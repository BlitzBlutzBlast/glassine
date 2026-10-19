import AppKit

/// A pipe table as the editor sees it.
///
/// The file keeps its `|` and `---`; the page shows a table. Each row's cells
/// are measured as styled and the narrower ones are padded — a kern on the
/// cell's last space, or on its opening pipe for a right-aligned column — so
/// every column lines up to its widest cell, whatever the font. The pipes
/// are drawn as hairlines the height of the row, the separator's dashes as a
/// rule across the cell, the header in the bold weight (GlassineLayoutManager
/// draws them; MarkdownStyler asks for the layout). Tab moves to the next
/// cell and ⇧Tab to the one before; Tab from the last cell adds a row.
enum MarkdownTable {

    /// On every `|` of a table; the value is the hairline's colour.
    static let pipeKey = NSAttributedString.Key("glassine.tablePipe")
    /// On the dashes and colons of the separator row; the value is the rule's colour.
    static let ruleKey = NSAttributedString.Key("glassine.tableRule")
    /// On every character of a table row: which row of its table it is.
    static let rowKey = NSAttributedString.Key("glassine.tableRow")
    /// On every character of a table row: the table's right edge, in points
    /// from the row's left, where the closing pipe of a row whose last cell
    /// wrapped is drawn — the pipe itself ends up at the end of the last line.
    static let edgeKey = NSAttributedString.Key("glassine.tableEdge")
    /// On the separator row's pipes, set small with the rest of the row:
    /// half the width of a body pipe, so the hairline sits where the other
    /// rows' do.
    static let pipeInsetKey = NSAttributedString.Key("glassine.tablePipeInset")

    enum Alignment { case left, center, right }

    struct Row {
        /// The paragraph, without its newline.
        let range: NSRange
        /// Absolute positions of the row's pipes.
        let pipes: [Int]
        /// Absolute ranges of what lies between the pipes, in column order.
        let cells: [NSRange]
    }

    struct Table {
        let rows: [Row]
        var alignments: [Alignment]
        var columns: Int { alignments.count }
    }

    // MARK: - Reading

    /// The dashes may be em or en dashes too: a separator typed with smart
    /// dashes on, before the editor learned to leave them alone, still reads.
    private static let separatorRx = try! NSRegularExpression(pattern: "^[ \\t]*\\|?[ \\t]*:?[-\u{2013}\u{2014}]+:?[ \\t]*(\\|[ \\t]*:?[-\u{2013}\u{2014}]+:?[ \\t]*)*\\|?[ \\t]*$")

    static func isSeparator(_ line: String) -> Bool {
        line.contains(where: { $0 == "-" || $0 == "\u{2013}" || $0 == "\u{2014}" })
            && separatorRx.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) != nil
    }

    /// A line that could be a row: at least one pipe outside a code span.
    static func looksLikeRow(_ line: String) -> Bool {
        line.contains("|") && !line.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The row's shape: its pipes (those outside code spans, and not escaped)
    /// and the cells between them. A row may leave off its first or last pipe.
    static func row(_ ns: NSString, paragraph: NSRange) -> Row {
        var pipes: [Int] = []
        var inCode = false
        var i = paragraph.location
        let end = paragraph.upperBoundValue
        while i < end {
            let c = ns.character(at: i)
            if c == 0x60 { inCode.toggle() }                      // `
            else if c == 0x7C, !inCode, i == paragraph.location || ns.character(at: i - 1) != 0x5C { pipes.append(i) }   // | not after \
            i += 1
        }
        var cells: [NSRange] = []
        var start = paragraph.location
        // A leading pipe opens the first cell; without one the line's start does.
        var bounds = pipes
        if let first = bounds.first, isBlank(ns, NSRange(location: paragraph.location, length: first - paragraph.location)) {
            start = first + 1
            bounds.removeFirst()
        }
        // A trailing pipe closes the last cell; without one the line's end does.
        var closesLast = false
        if let last = bounds.last, isBlank(ns, NSRange(location: last + 1, length: end - last - 1)) {
            closesLast = true
            bounds.removeLast()
        }
        for p in bounds {
            cells.append(NSRange(location: start, length: p - start))
            start = p + 1
        }
        let lastEnd = closesLast ? (pipes.last ?? end) : end
        cells.append(NSRange(location: start, length: max(0, lastEnd - start)))
        return Row(range: paragraph, pipes: pipes, cells: cells)
    }

    private static func isBlank(_ ns: NSString, _ r: NSRange) -> Bool {
        guard r.length > 0 else { return true }
        return ns.substring(with: r).trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// A table from consecutive rows, when the second is a separator.
    static func table(_ ns: NSString, paragraphs: [NSRange]) -> Table? {
        guard paragraphs.count >= 2, isSeparator(ns.substring(with: paragraphs[1])) else { return nil }
        let rows = paragraphs.map { row(ns, paragraph: $0) }
        let alignments = rows[1].cells.map { cell -> Alignment in
            let t = ns.substring(with: cell).trimmingCharacters(in: .whitespaces)
            let l = t.hasPrefix(":"), r = t.hasSuffix(":")
            return l && r ? .center : r ? .right : .left
        }
        return Table(rows: rows, alignments: alignments)
    }

    /// The table a position is in, read from the text around it.
    static func table(_ ns: NSString, around location: Int) -> Table? {
        let block = blockRange(ns, around: location)
        var paragraphs: [NSRange] = []
        ns.enumerateSubstrings(in: block, options: [.byParagraphs, .substringNotRequired]) { _, r, _, _ in paragraphs.append(r) }
        return table(ns, paragraphs: paragraphs)
    }

    /// The run of pipe lines around a position, as one range.
    static func blockRange(_ ns: NSString, around location: Int) -> NSRange {
        var r = ns.paragraphRange(for: NSRange(location: min(location, ns.length), length: 0))
        guard looksLikeRow(ns.substring(with: r)) else { return r }
        while r.location > 0 {
            let prev = ns.paragraphRange(for: NSRange(location: r.location - 1, length: 0))
            guard looksLikeRow(ns.substring(with: prev)) else { break }
            r = NSUnionRange(r, prev)
        }
        while r.upperBoundValue < ns.length {
            let next = ns.paragraphRange(for: NSRange(location: r.upperBoundValue, length: 0))
            guard looksLikeRow(ns.substring(with: next)) else { break }
            r = NSUnionRange(r, next)
        }
        return r
    }

    // MARK: - Layout

    /// Pads the cells so the columns line up, and marks the pipes, the
    /// separator and the header for drawing. Fonts and inline styles are
    /// already on the text; the kerns go on top of whatever kern is there.
    /// The table is as wide as its widest cells, up to `availableWidth`: a
    /// last column that would run past the page is cut to what fits, and a
    /// cell longer than that wraps under its own column (the row's head
    /// indent) rather than under the row.
    static func layOut(_ table: Table, in storage: NSTextStorage, config: StyleConfig,
                       pipeColor: NSColor, ruleColor: NSColor, headerFont: NSFont,
                       rowParagraph: NSParagraphStyle, lastRowParagraph: NSParagraphStyle, availableWidth: CGFloat) {
        let ns = storage.string as NSString
        let columns = table.columns
        guard columns > 0 else { return }
        let bodyPipe = ("|" as NSString).size(withAttributes: [.font: config.bodyFont]).width

        for (index, row) in table.rows.enumerated() {
            storage.addAttribute(rowKey, value: index, range: row.range)
            if index == 1 {
                // The separator is a rule, not a line of text: a short line.
                storage.enumerateAttribute(.font, in: row.range, options: []) { value, r, _ in
                    let f = (value as? NSFont) ?? config.bodyFont
                    storage.addAttribute(.font, value: f.withSize((f.pointSize * 0.45).rounded()), range: r)
                }
            }
            for p in row.pipes {
                storage.addAttribute(.foregroundColor, value: pipeColor, range: NSRange(location: p, length: 1))
                storage.addAttribute(pipeKey, value: pipeColor, range: NSRange(location: p, length: 1))
                if index == 1 {
                    // A small pipe advances like a body pipe and is drawn centred like one.
                    let f = storage.attribute(.font, at: p, effectiveRange: nil) as? NSFont ?? config.bodyFont
                    let w = ("|" as NSString).size(withAttributes: [.font: f]).width
                    if bodyPipe - w > 0.1 { addKern(bodyPipe - w, at: p, in: storage) }
                    storage.addAttribute(pipeInsetKey, value: bodyPipe / 2, range: NSRange(location: p, length: 1))
                }
            }
            if index == 0 {
                for cell in row.cells where cell.length > 0 {
                    storage.enumerateAttribute(.font, in: cell, options: []) { value, r, _ in
                        let f = (value as? NSFont) ?? headerFont
                        storage.addAttribute(.font, value: f.withTraits(.bold), range: r)
                    }
                }
            } else if index == 1 {
                for cell in row.cells where cell.length > 0 {
                    storage.addAttribute(.foregroundColor, value: ruleColor, range: cell)
                    storage.addAttribute(ruleKey, value: ruleColor, range: cell)
                }
            }
        }

        // Every cell measured as it will be drawn, then the widest in each column.
        var widths = [CGFloat](repeating: 0, count: columns)
        var measured: [[CGFloat]] = []
        for row in table.rows {
            var ws: [CGFloat] = []
            for (c, cell) in row.cells.enumerated() {
                let w = width(of: cell, in: storage, hideSyntax: config.hideSyntax)
                ws.append(w)
                if c < columns { widths[c] = max(widths[c], w) }
            }
            measured.append(ws)
        }
        // A cell is at least a few spaces wide, so an empty column has room to type in.
        let minimum = ("    " as NSString).size(withAttributes: [.font: config.bodyFont]).width
        for c in 0..<columns { widths[c] = max(widths[c], minimum) }
        // The last column stops at the page's edge; what is longer wraps.
        let last = columns - 1
        var targets = widths
        let before = widths[0..<last].reduce(0, +) + CGFloat(columns + 1) * bodyPipe
        let room = availableWidth - before - 4
        if room > 0, widths[last] > room { targets[last] = max(room, minimum) }

        for (r, row) in table.rows.enumerated() {
            for (c, cell) in row.cells.enumerated() where c < columns {
                let pad = targets[c] - measured[r][c]
                guard pad > 0.5 else { continue }
                let opening: Int? = row.pipes.first { $0 == cell.location - 1 }
                let closing = cell.upperBoundValue   // the pipe after the cell, if any
                let hasClosing = row.pipes.contains(closing)
                // The cell's own last character carries the padding before its
                // pipe; the opening pipe carries padding that goes before the text.
                let tail: Int? = cell.length > 0 ? cell.upperBoundValue - 1 : opening
                switch table.alignments[c] {
                case .left:
                    if let t = tail { addKern(pad, at: t, in: storage) }
                    else if hasClosing { addKern(pad, at: closing - 1, in: storage) }
                case .right:
                    if let o = opening { addKern(pad, at: o, in: storage) }
                    else if let t = tail { addKern(pad, at: t, in: storage) }
                case .center:
                    let half = (pad / 2).rounded()
                    if let o = opening { addKern(half, at: o, in: storage) } else if let t = tail { addKern(half, at: t, in: storage) }
                    if let t = tail { addKern(pad - half, at: t, in: storage) }
                }
            }
        }

        // Where each row's last column begins, measured as padded, for the
        // lines of a cell that wraps; and the table's right edge, read off
        // the first row whose last cell fits, for a closing pipe carried to a
        // later line by one that did not.
        var edge: CGFloat?
        var starts: [CGFloat] = []
        for (r, row) in table.rows.enumerated() {
            guard let cell = row.cells.last else { starts.append(0); continue }
            let textStart = textRange(of: cell, in: ns).location
            starts.append(width(of: NSRange(location: row.range.location, length: textStart - row.range.location),
                                in: storage, hideSyntax: config.hideSyntax))
            if edge == nil, r != 1, measured[r][last] <= targets[last] + 0.5,
               let closing = row.pipes.last, closing == cell.upperBoundValue {
                edge = width(of: NSRange(location: row.range.location, length: closing - row.range.location),
                             in: storage, hideSyntax: config.hideSyntax) + bodyPipe / 2
            }
        }
        let tableEdge = edge ?? ((starts.first ?? 0) + targets[last] + bodyPipe / 2)
        for (r, row) in table.rows.enumerated() {
            let enclosing = NSRange(location: row.range.location,
                                    length: min(ns.length, row.range.upperBoundValue + 1) - row.range.location)
            // Rows sit flush so the hairlines join; the last keeps the page's spacing after it.
            let style = (r == table.rows.count - 1 ? lastRowParagraph : rowParagraph).mutableCopy() as! NSMutableParagraphStyle
            style.headIndent = starts[r]
            storage.addAttribute(.paragraphStyle, value: style, range: enclosing)
            storage.addAttribute(edgeKey, value: tableEdge, range: row.range)
        }
    }

    private static func addKern(_ amount: CGFloat, at index: Int, in storage: NSTextStorage) {
        guard index >= 0, index < storage.length else { return }
        let existing = storage.attribute(.kern, at: index, effectiveRange: nil) as? CGFloat ?? 0
        storage.addAttribute(.kern, value: existing + amount, range: NSRange(location: index, length: 1))
    }

    /// The width a cell's text takes as drawn: its fonts and kerns, less any
    /// marker that is hidden.
    private static func width(of range: NSRange, in storage: NSTextStorage, hideSyntax: Bool) -> CGFloat {
        guard range.length > 0 else { return 0 }
        let piece = NSMutableAttributedString(attributedString: storage.attributedSubstring(from: range))
        piece.removeAttribute(pipeKey, range: NSRange(location: 0, length: piece.length))
        if hideSyntax {
            var hidden: [NSRange] = []
            piece.enumerateAttribute(Syntax.hiddenKey, in: NSRange(location: 0, length: piece.length), options: []) { v, r, _ in
                if v != nil { hidden.append(r) }
            }
            for r in hidden.reversed() { piece.deleteCharacters(in: r) }
        }
        return piece.size().width
    }

    // MARK: - Moving between cells

    struct Move {
        /// What to select afterwards: the words of the cell moved to.
        var selection: NSRange
        /// Text to write first — a fresh row — and where.
        var insert: (at: Int, text: String)?
    }

    /// Where Tab goes from a position: the next cell's text, or nil when the
    /// position is not in a table. From the last cell a new row is added.
    static func nextCell(from location: Int, in storage: NSTextStorage, backward: Bool) -> Move? {
        let ns = storage.string as NSString
        guard let table = table(ns, around: location) else { return nil }
        // The separator's cells are not for writing in: Tab from the last
        // heading goes to the first cell under it.
        let cells = table.rows.enumerated().filter { $0.offset != 1 }.flatMap { $0.element.cells }
        guard let here = cells.firstIndex(where: { NSLocationInRange(location, NSRange(location: $0.location, length: $0.length + 1)) })
            ?? cells.lastIndex(where: { $0.location <= location }) else { return nil }
        let target = here + (backward ? -1 : 1)
        if target < 0 { return nil }
        if target >= cells.count {
            // A fresh row under the last, shaped like the one above it.
            let last = table.rows.last!
            let text = "\n|" + Array(repeating: "  |", count: table.columns).joined()
            let at = last.range.upperBoundValue
            return Move(selection: NSRange(location: at + 3, length: 0), insert: (at, text))
        }
        return Move(selection: textRange(of: cells[target], in: ns), insert: nil)
    }

    /// The words of a cell, without the spaces that keep them off the pipes.
    static func textRange(of cell: NSRange, in ns: NSString) -> NSRange {
        var start = cell.location, end = cell.upperBoundValue
        while start < end, ns.character(at: start) == 0x20 { start += 1 }
        while end > start, ns.character(at: end - 1) == 0x20 { end -= 1 }
        // An empty cell: the caret goes after its first space, at the left,
        // where the padding (on the last space) is not.
        if start == end, cell.length >= 2 { return NSRange(location: cell.location + 1, length: 0) }
        return NSRange(location: start, length: end - start)
    }
}
