import AppKit
let html = "<h2>Shopping</h2><ul><li>Milk</li><li><b>Eggs</b>, a dozen</li></ul>"
let pb = NSPasteboard.general
pb.clearContents(); pb.declareTypes([.html, .string], owner: nil)
pb.setData(html.data(using: .utf8)!, forType: .html); pb.setString("Shopping\nMilk\nEggs, a dozen", forType: .string)
print("clipboard set")
