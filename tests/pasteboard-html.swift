import AppKit
// Puts an HTML flavour and its lossy plain flavour on the clipboard, the way a
// browser does, for a paste test by hand or script: swift tests/pasteboard-html.swift
let html = "<h2>Shopping</h2><ul><li>Milk</li><li><b>Eggs</b>, a dozen</li></ul><ol><li>First</li><li>Second</li></ol><p>See <a href=\"https://glassine.ink\">the site</a>.</p>"
let plain = "Shopping\nMilk\nEggs, a dozen\nFirst\nSecond\nSee the site."
let pb = NSPasteboard.general
pb.clearContents()
pb.declareTypes([.html, .string], owner: nil)
pb.setData(html.data(using: .utf8)!, forType: .html)
pb.setString(plain, forType: .string)
print("clipboard set")
