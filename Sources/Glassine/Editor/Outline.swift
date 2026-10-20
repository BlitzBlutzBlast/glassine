import Foundation

/// The headings of a page, in order, for the outline beside the editor.
///
/// Only `#` headings count, up to three spaces in, with a space (or nothing)
/// after the marks; lines inside a fenced code block are code, not headings.
/// A title is shown as it reads: its closing marks and its inline markers
/// gone, a link as its words.
enum Outline {

    struct Heading: Identifiable, Equatable {
        /// Where the heading's line starts, in UTF-16 units: what the editor selects.
        let location: Int
        let level: Int
        let title: String
        var id: Int { location }
    }

    private static let atx = try! NSRegularExpression(pattern: "^ {0,3}(#{1,6})(?:[ \\t]+(.*?))?[ \\t]*$")
    private static let closing = try! NSRegularExpression(pattern: "[ \\t]+#+$")
    private static let link = try! NSRegularExpression(pattern: "!?\\[([^\\]]*)\\]\\([^)]*\\)")
    private static let markers = try! NSRegularExpression(pattern: "\\*\\*|__|~~|==|`|(?<![\\w*])\\*(?=\\S)|(?<=\\S)\\*(?![\\w*])")

    static func headings(in text: String) -> [Heading] {
        let ns = text as NSString
        var found: [Heading] = []
        var fence: String?
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byLines]) { line, range, _, _ in
            guard let line else { return }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let open = fence {
                if trimmed.hasPrefix(open) { fence = nil }
                return
            }
            if trimmed.hasPrefix("```") { fence = "```"; return }
            if trimmed.hasPrefix("~~~") { fence = "~~~"; return }
            guard trimmed.hasPrefix("#") else { return }
            let lineNS = line as NSString
            guard let m = atx.firstMatch(in: line, range: NSRange(location: 0, length: lineNS.length)) else { return }
            let level = m.range(at: 1).length
            var title = m.range(at: 2).location == NSNotFound ? "" : lineNS.substring(with: m.range(at: 2))
            title = replace(closing, in: title, with: "")
            title = replace(link, in: title, with: "$1")
            title = replace(markers, in: title, with: "")
            title = title.trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { return }
            found.append(Heading(location: range.location, level: level, title: title))
        }
        return found
    }

    /// The heading the caret is under: the last one that starts at or before it.
    static func current(in headings: [Heading], caret: Int) -> Heading? {
        headings.last { $0.location <= caret }
    }

    private static func replace(_ rx: NSRegularExpression, in s: String, with template: String) -> String {
        rx.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: template)
    }
}
