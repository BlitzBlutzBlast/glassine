import AppKit

/// What a paste puts on the page.
///
/// The plain-text flavour of most clipboards is the one thing on them that
/// has lost its shape: Chrome, Word, Pages and Notes all drop the bullets and
/// the numbers from it, headings become ordinary lines, links lose their
/// addresses. The rich flavour — RTF or HTML — still has all of that, so a
/// paste reads it and writes the Markdown the editor would have written:
/// `- ` and `1. ` for the lists, nested by their depth, `#` for a heading
/// that was one, `**` and `*` for the weight and the slant, `[text](url)`
/// for a link, a pipe table for a table. Text copied out of Glassine itself
/// is Markdown already and goes in as it is; so does anything with no
/// structure to keep. Edit → Paste as Plain Text (⌥⇧⌘V) is the raw string,
/// for the time the conversion is not what was wanted.
enum PasteMarkdown {

    /// The type Glassine adds to its own copies, so a paste of its own text
    /// is never converted twice.
    static let ownType = NSPasteboard.PasteboardType("com.alexlibre.glassine.markdown")

    /// The text a paste of this pasteboard inserts; nil when there is no text on it.
    static func text(from pb: NSPasteboard) -> String? {
        let types = pb.types ?? []
        let plain = pb.string(forType: .string)
        if types.contains(ownType) { return plain }
        var rich: NSAttributedString?
        var fromHTML = false
        if types.contains(.rtfd), let data = pb.data(forType: .rtfd) {
            rich = NSAttributedString(rtfd: data, documentAttributes: nil)
        }
        if rich == nil, types.contains(.rtf), let data = pb.data(forType: .rtf) {
            rich = NSAttributedString(rtf: data, documentAttributes: nil)
        }
        if rich == nil, types.contains(.html), let data = pb.data(forType: .html) {
            rich = NSAttributedString(html: data, options: [.documentType: NSAttributedString.DocumentType.html,
                                                            .characterEncoding: String.Encoding.utf8.rawValue],
                                      documentAttributes: nil)
            fromHTML = rich != nil
        }
        if let rich, rich.length > 0 {
            let md = markdown(from: rich, fromHTML: fromHTML)
            if !md.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return md }
        }
        guard let plain else { return nil }
        return tidyPlain(plain)
    }

    // MARK: - Plain text

    /// Plain text with the bullets and numbers some apps leave in it turned
    /// into list markers the editor knows: `•` and its relatives become `-`,
    /// `1)` becomes `1.`, a leading tab becomes the editor's four spaces.
    static func tidyPlain(_ s: String) -> String {
        let lines = s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        return lines.map { line -> String in
            var l = Substring(line)
            var indent = ""
            while let c = l.first, c == " " || c == "\t" {
                indent += c == "\t" ? "    " : " "
                l = l.dropFirst()
            }
            if let c = l.first, Self.bulletGlyphs.contains(c), l.dropFirst().first.map({ $0 == " " || $0 == "\t" }) ?? false {
                return indent + "- " + l.dropFirst(2).drop(while: { $0 == " " || $0 == "\t" })
            }
            if let m = Self.numberedRx.firstMatch(in: String(l), range: NSRange(location: 0, length: (String(l) as NSString).length)) {
                let ns = String(l) as NSString
                return indent + ns.substring(with: m.range(at: 1)) + ". " + ns.substring(with: m.range(at: 2))
            }
            return indent + l
        }.joined(separator: "\n")
    }

    private static let bulletGlyphs: Set<Character> = ["•", "◦", "▪", "●", "○", "■", "‣", "⁃"]
    private static let numberedRx = try! NSRegularExpression(pattern: "^(\\d{1,3})[.)][ \\t]+(.*)$")

    // MARK: - Rich text

    /// Markdown for an attributed string, paragraph by paragraph.
    static func markdown(from rich: NSAttributedString, fromHTML: Bool) -> String {
        let base = baseFontSize(rich)
        let string = rich.string as NSString
        var out: [String] = []
        var table: TableBuilder?
        var listCounters: [ObjectIdentifier: Int] = [:]
        var previousLists: [NSTextList] = []
        var inCode = false

        // Paragraphs end at \n, \r, U+2029; a U+2028 line break stays inside one.
        var location = 0
        while location < string.length {
            let paraRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            var contentRange = paraRange
            // Drop the terminator.
            if paraRange.length > 0 {
                let last = string.character(at: paraRange.location + paraRange.length - 1)
                if last == 0x0A || last == 0x0D || last == 0x2029 { contentRange.length -= 1 }
            }
            location = paraRange.location + max(paraRange.length, 1)

            let attrs = rich.attributes(at: contentRange.location, longestEffectiveRange: nil, in: contentRange)
            let style = attrs[.paragraphStyle] as? NSParagraphStyle
            let blocks = style?.textBlocks ?? []

            // A cell of a table collects into the table; anything else flushes it.
            if let cell = blocks.compactMap({ $0 as? NSTextTableBlock }).last {
                if table == nil || table!.table !== cell.table {
                    if let t = table { out.append(contentsOf: t.lines()) }
                    table = TableBuilder(table: cell.table)
                }
                table!.add(inline(rich, range: contentRange, base: base), row: cell.startingRow, column: cell.startingColumn)
                continue
            }
            if let t = table { out.append(contentsOf: t.lines()); table = nil }

            let lists = style?.textLists ?? []
            // The importer writes the list's marker into the text ("\t•\t",
            // "\t1.\t"), styled like the words after it; it comes off before
            // the words are read, so a bold item does not swallow it.
            if !lists.isEmpty {
                let raw = rawText(rich, range: contentRange)
                let skip = listMarkerLength(raw)
                contentRange = NSRange(location: contentRange.location + skip, length: contentRange.length - skip)
            }
            let body = inline(rich, range: contentRange, base: base)
            let isMono = paragraphIsMonospace(rich, range: contentRange)

            // A code paragraph: fenced, as a run of them.
            if isMono, lists.isEmpty {
                if !inCode { out.append("```"); inCode = true }
                out.append(rawText(rich, range: contentRange))
                continue
            } else if inCode {
                out.append("```"); inCode = false
            }

            if !lists.isEmpty {
                let depth = lists.count - 1
                let list = lists[depth]
                // A list seen for the first time, or one re-entered after a
                // different list at this depth, counts from one again.
                let id = ObjectIdentifier(list)
                if previousLists.count <= depth || previousLists[depth] !== list { listCounters[id] = 0 }
                let n = (listCounters[id] ?? 0) + 1
                listCounters[id] = n
                let marker = list.isOrdered ? "\(n)." : "-"
                out.append(String(repeating: "    ", count: depth) + marker + " " + body)
                previousLists = lists
                continue
            }
            previousLists = []

            // A heading: a short paragraph set noticeably larger than the body.
            let size = paragraphFontSize(rich, range: contentRange)
            let trimmed = body.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty, trimmed.count <= 160, size > 0, base > 0 {
                let ratio = size / base
                let level = ratio >= 1.7 ? 1 : ratio >= 1.35 ? 2 : ratio >= 1.12 ? 3 : 0
                if level > 0 {
                    out.append(String(repeating: "#", count: level) + " " + unbold(trimmed))
                    continue
                }
            }
            // A quotation, when the source says so.
            if fromHTML, !blocks.isEmpty, !trimmed.isEmpty {
                out.append("> " + trimmed)
                continue
            }
            out.append(body.trimmingTrailingWhitespace())
        }
        if inCode { out.append("```") }
        if let t = table { out.append(contentsOf: t.lines()) }
        // Blank lines at the ends are the source's margins, not its text.
        while out.first?.isEmpty == true { out.removeFirst() }
        while out.last?.isEmpty == true { out.removeLast() }
        // Three or more blank lines in a row are two.
        var collapsed: [String] = []
        var blanks = 0
        for line in out {
            if line.isEmpty { blanks += 1; if blanks > 2 { continue } } else { blanks = 0 }
            collapsed.append(line)
        }
        return collapsed.joined(separator: "\n")
    }

    /// How many UTF-16 units of marker the importer wrote at the start of a
    /// list paragraph: "\t•\t" or "\t1.\t" from Cocoa, "• " or "1. " from
    /// some sources, nothing from others.
    private static func listMarkerLength(_ s: String) -> Int {
        let ns = s as NSString
        for pattern in ["^\\t?[^\\t\\n]{0,8}\\t", "^[•◦▪●○■‣⁃]\\s+", "^(\\d{1,3}|[a-zA-Z]|[ivxIVX]{1,5})[.)]\\s+"] {
            if let r = s.range(of: pattern, options: .regularExpression) {
                return NSRange(r, in: s).length
            }
        }
        _ = ns
        return 0
    }

    /// A heading is already a weight of its own; `**` inside it is noise.
    static func unbold(_ s: String) -> String {
        guard s.hasPrefix("**"), s.hasSuffix("**"), s.count > 4 else { return s }
        let inner = String(s.dropFirst(2).dropLast(2))
        return inner.contains("**") ? s : inner
    }

    // MARK: Inline runs

    private struct Run {
        var text: String
        var bold = false, italic = false, strike = false, code = false
        var link: String?
        func sameStyle(as o: Run) -> Bool { bold == o.bold && italic == o.italic && strike == o.strike && code == o.code && link == o.link }
    }

    /// The paragraph as Markdown inline text: runs of the same style merged,
    /// marks placed outside any spaces at a run's ends.
    private static func inline(_ rich: NSAttributedString, range: NSRange, base: CGFloat) -> String {
        var runs: [Run] = []
        rich.enumerateAttributes(in: range, options: []) { attrs, r, _ in
            var text = (rich.string as NSString).substring(with: r)
            text = text.replacingOccurrences(of: "\u{FFFC}", with: "")
                .replacingOccurrences(of: "\u{2028}", with: "\n")
            guard !text.isEmpty else { return }
            var run = Run(text: text)
            if let font = attrs[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                run.bold = traits.contains(.bold) || (font.fontDescriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any])
                    .flatMap { $0[.weight] as? CGFloat }.map { $0 >= 0.3 } ?? false
                run.italic = traits.contains(.italic)
                run.code = traits.contains(.monoSpace) || font.isFixedPitch || Self.looksMonospace(font)
            }
            if let s = attrs[.strikethroughStyle] as? Int, s != 0 { run.strike = true }
            if let link = attrs[.link] {
                run.link = (link as? URL)?.absoluteString ?? (link as? String)
            }
            if let last = runs.last, last.sameStyle(as: run) {
                runs[runs.count - 1].text += text
            } else {
                runs.append(run)
            }
        }
        var out = ""
        for run in runs {
            let lead = String(run.text.prefix(while: { $0 == " " || $0 == "\t" }))
            let trail = String(run.text.reversed().prefix(while: { $0 == " " || $0 == "\t" }).reversed())
            var core = String(run.text.dropFirst(lead.count).dropLast(trail.count))
            if core.isEmpty { out += run.text; continue }
            if run.code {
                core = "`" + core + "`"
            } else {
                if run.bold && run.italic { core = "***" + core + "***" }
                else if run.bold { core = "**" + core + "**" }
                else if run.italic { core = "*" + core + "*" }
                if run.strike { core = "~~" + core + "~~" }
            }
            if let link = run.link, !link.isEmpty {
                let bare = core.trimmingCharacters(in: CharacterSet(charactersIn: "*~`"))
                func norm(_ s: String) -> String {
                    var t = s.lowercased().replacingOccurrences(of: "mailto:", with: "")
                    if t.hasSuffix("/") { t.removeLast() }
                    return t
                }
                core = norm(bare) == norm(link) ? bare : "[\(core)](\(link))"
            }
            out += lead + core + trail
        }
        return out
    }

    private static func rawText(_ rich: NSAttributedString, range: NSRange) -> String {
        (rich.string as NSString).substring(with: range).replacingOccurrences(of: "\u{FFFC}", with: "")
    }

    private static func looksMonospace(_ font: NSFont) -> Bool {
        let name = font.familyName?.lowercased() ?? font.fontName.lowercased()
        return name.contains("mono") || name.contains("courier") || name.contains("menlo") || name.contains("consolas") || name.contains("code")
    }

    /// The point size most of the text is set in, by characters.
    private static func baseFontSize(_ rich: NSAttributedString) -> CGFloat {
        var weights: [CGFloat: Int] = [:]
        rich.enumerateAttribute(.font, in: NSRange(location: 0, length: rich.length), options: []) { v, r, _ in
            guard let f = v as? NSFont else { return }
            weights[(f.pointSize * 2).rounded() / 2, default: 0] += r.length
        }
        return weights.max { $0.value < $1.value }?.key ?? 0
    }

    private static func paragraphFontSize(_ rich: NSAttributedString, range: NSRange) -> CGFloat {
        var weights: [CGFloat: Int] = [:]
        rich.enumerateAttribute(.font, in: range, options: []) { v, r, _ in
            guard let f = v as? NSFont else { return }
            let text = (rich.string as NSString).substring(with: r)
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            weights[(f.pointSize * 2).rounded() / 2, default: 0] += r.length
        }
        return weights.max { $0.value < $1.value }?.key ?? 0
    }

    private static func paragraphIsMonospace(_ rich: NSAttributedString, range: NSRange) -> Bool {
        guard range.length > 0 else { return false }
        var mono = 0, total = 0
        rich.enumerateAttribute(.font, in: range, options: []) { v, r, _ in
            let text = (rich.string as NSString).substring(with: r)
            let n = text.trimmingCharacters(in: .whitespaces).count
            guard n > 0 else { return }
            total += n
            if let f = v as? NSFont, f.fontDescriptor.symbolicTraits.contains(.monoSpace) || f.isFixedPitch || looksMonospace(f) { mono += n }
        }
        return total > 0 && mono == total
    }

    // MARK: Tables

    /// Cells gathered by row and column, written out as a pipe table.
    private struct TableBuilder {
        let table: NSTextTable
        var cells: [Int: [Int: String]] = [:]
        mutating func add(_ text: String, row: Int, column: Int) {
            let clean = text.replacingOccurrences(of: "|", with: "\\|")
                .replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
            cells[row, default: [:]][column, default: ""] += (cells[row]?[column]?.isEmpty == false ? " " : "") + clean
        }
        func lines() -> [String] {
            let rows = cells.keys.sorted()
            guard let first = rows.first else { return [] }
            let columns = max(table.numberOfColumns, (cells.values.flatMap { $0.keys }.max() ?? 0) + 1)
            func line(_ r: Int, header: Bool = false) -> String {
                "| " + (0..<columns).map { header ? PasteMarkdown.unbold(cells[r]?[$0] ?? "") : (cells[r]?[$0] ?? "") }.joined(separator: " | ") + " |"
            }
            var out = [line(first, header: true), "| " + Array(repeating: "---", count: columns).joined(separator: " | ") + " |"]
            for r in rows.dropFirst() { out.append(line(r)) }
            return out
        }
    }
}

private extension String {
    func trimmingTrailingWhitespace() -> String {
        var s = Substring(self)
        while let c = s.last, c == " " || c == "\t" { s = s.dropLast() }
        return String(s)
    }
}
