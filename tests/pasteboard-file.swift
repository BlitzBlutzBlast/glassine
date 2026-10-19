import AppKit
// Puts a file's HTML on the clipboard with a plain flavour beside it, the way a
// browser does: swift tests/pasteboard-file.swift page.html [plain.txt]
let args = CommandLine.arguments
let html = try! String(contentsOfFile: args[1], encoding: .utf8)
let plain = args.count > 2 ? try! String(contentsOfFile: args[2], encoding: .utf8) : html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
let pb = NSPasteboard.general
pb.clearContents()
pb.declareTypes([.html, .string], owner: nil)
pb.setData(html.data(using: .utf8)!, forType: .html)
pb.setString(plain, forType: .string)
print("clipboard set")
