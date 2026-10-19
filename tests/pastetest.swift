import AppKit

// Paste conversion, checked against what Chrome, Word, Notes and the like put
// on the clipboard. Run with tests/pastetest.sh.

var failures = 0
func check(_ name: String, _ got: String, _ want: String) {
    if got == want { print("ok   \(name)") } else {
        failures += 1
        print("FAIL \(name)\n--- got\n\(got)\n--- want\n\(want)\n---")
    }
}
func html(_ s: String) -> String {
    let rich = NSAttributedString(html: s.data(using: .utf8)!, options: [.documentType: NSAttributedString.DocumentType.html,
                                                                     .characterEncoding: String.Encoding.utf8.rawValue],
                                  documentAttributes: nil)!
    return PasteMarkdown.markdown(from: rich, fromHTML: true)
}
func rtf(_ s: String) -> String {
    // Round-trip through RTF, the way Word, Pages, TextEdit and Notes hand text over.
    let rich = NSAttributedString(html: s.data(using: .utf8)!, options: [.documentType: NSAttributedString.DocumentType.html,
                                                                     .characterEncoding: String.Encoding.utf8.rawValue],
                                  documentAttributes: nil)!
    let data = rich.rtf(from: NSRange(location: 0, length: rich.length), documentAttributes: [:])!
    let back = NSAttributedString(rtf: data, documentAttributes: nil)!
    return PasteMarkdown.markdown(from: back, fromHTML: false)
}

check("bullets", html("<ul><li>One</li><li>Two</li><li>Three</li></ul>"), "- One\n- Two\n- Three")
check("numbers", html("<ol><li>First</li><li>Second</li></ol>"), "1. First\n2. Second")
check("nested", html("<ul><li>Top<ul><li>Inner</li></ul></li><li>Back</li></ul>"), "- Top\n    - Inner\n- Back")
check("two lists", html("<ol><li>A</li></ol><p>between</p><ol><li>B</li></ol>"), "1. A\nbetween\n1. B")
check("heading", html("<h1>Title</h1><p>Body text here.</p><h2>Second</h2><p>More.</p>"), "# Title\nBody text here.\n## Second\nMore.")
check("inline", html("<p>Some <b>bold</b> and <i>slanted</i> and <b><i>both</i></b> and <s>gone</s> and <code>code</code>.</p>"),
      "Some **bold** and *slanted* and ***both*** and ~~gone~~ and `code`.")
check("link", html("<p>See <a href=\"https://glassine.ink\">the site</a> and <a href=\"https://x.y\">https://x.y</a>.</p>"),
      "See [the site](https://glassine.ink/) and https://x.y.")
check("bold with spaces", html("<p>a<b> bold </b>b</p>"), "a **bold** b")
check("table", html("<table><tr><th>Name</th><th>Age</th></tr><tr><td>Ann</td><td>3</td></tr></table>"),
      "| Name | Age |\n| --- | --- |\n| Ann | 3 |")
check("code block", html("<pre><code>let x = 1\nlet y = 2</code></pre><p>after</p>"), "```\nlet x = 1\nlet y = 2\n```\nafter")
check("rtf bullets", rtf("<ul><li>One</li><li>Two</li></ul>"), "- One\n- Two")
check("rtf numbers", rtf("<ol><li>One</li><li>Two</li><li>Three</li></ol>"), "1. One\n2. Two\n3. Three")
check("rtf heading", rtf("<h1>Title</h1><p>Body text here.</p>"), "# Title\nBody text here.")
check("chrome styled", html("<meta charset='utf-8'><ul style=\"margin:0\"><li style=\"font-weight:400\"><span style=\"font-weight:700\">Bold</span> item</li><li>Plain</li></ul>"),
      "- **Bold** item\n- Plain")
check("plain tidy", PasteMarkdown.tidyPlain("• One\n\t• Two\n1) Three\n2)\tFour\nplain – dash"), "- One\n    - Two\n1. Three\n2. Four\nplain – dash")
check("smart-dashed separator", PasteMarkdown.tidyPlain("| Level | IC7 |\n| — | — |\n| Team | CoE |\n|–|:–:|\nso — then"),
      "| Level | IC7 |\n| --- | --- |\n| Team | CoE |\n|--|:--:|\nso — then")
check("tabs become a table", PasteMarkdown.text(fromPlain: "Book\tPages\nThe Peregrine\t191\nPilgrim at Tinker Creek\t290\n"),
      "| Book | Pages |\n| --- | --- |\n| The Peregrine | 191 |\n| Pilgrim at Tinker Creek | 290 |")
check("tabs with a pipe", PasteMarkdown.tableFromTabs("a|b\tc\nd\te") ?? "nil", "| a\\|b | c |\n| --- | --- |\n| d | e |")
check("indented code is not a table", PasteMarkdown.tableFromTabs("\tlet x = 1\n\tlet y = 2") == nil ? "nil" : "table", "nil")
check("ragged tabs are not a table", PasteMarkdown.tableFromTabs("a\tb\nc\td\te") == nil ? "nil" : "table", "nil")
check("one line is not a table", PasteMarkdown.tableFromTabs("a\tb") == nil ? "nil" : "table", "nil")
check("html with a markdown separator", html("<p>| a | b |</p><p>| — | — |</p><p>| 1 | 2 |</p>"), "| a | b |\n| --- | --- |\n| 1 | 2 |")

print(failures == 0 ? "all passed" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
