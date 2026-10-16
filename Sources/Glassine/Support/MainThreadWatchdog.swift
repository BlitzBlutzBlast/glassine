import Darwin
import Foundation
import os

/// Keeps an eye on the main thread from a thread of its own, so a freeze
/// leaves a trace instead of a shrug.
///
/// Every quarter second it asks the main queue to answer. When the answer is
/// a second late, the main thread is held still for a moment, its stack is
/// read, and it is let go; if it is still stuck four seconds later its stack
/// is read again. The frames go to `~/Library/Logs/Glassine/stall-….txt` with
/// a line in the unified log (`subsystem:com.alexlibre.glassine
/// category:watchdog`), and the report is finished with the stall's full
/// length once the main thread answers.
///
/// Nothing allocates while the main thread is stopped — it may be stopped
/// inside malloc, holding its lock — so the frames land in a buffer set up in
/// advance and are looked up only after the thread is running again.
enum MainThreadWatchdog {
    /// How long the main thread may go without answering before its stack is read.
    static let threshold: TimeInterval = 1.0
    /// How much longer before a second reading, to tell one long wait from churn.
    private static let secondLook: TimeInterval = 4.0
    private static let maxFrames = 96
    private static let maxReports = 40

    private static var mainThread: thread_t = 0
    private static var stackLow: UInt = 0
    private static var stackHigh: UInt = 0
    private static let frames = UnsafeMutablePointer<UInt>.allocate(capacity: maxFrames)
    private static var started = false
    private static let log = Logger(subsystem: "com.alexlibre.glassine", category: "watchdog")

    /// Where the reports go.
    static var folder: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library", isDirectory: true)
        return library.appendingPathComponent("Logs/Glassine", isDirectory: true)
    }

    /// From the main thread, once, at launch.
    static func start() {
        guard Thread.isMainThread, !started else { return }
        started = true
        mainThread = mach_thread_self()
        let top = UInt(bitPattern: pthread_get_stackaddr_np(pthread_self()))
        let size = UInt(pthread_get_stacksize_np(pthread_self()))
        stackHigh = top
        stackLow = top &- size
        let thread = Thread { run() }
        thread.name = "glassine.watchdog"
        thread.qualityOfService = .utility
        thread.stackSize = 512 * 1024
        thread.start()
    }

    private static func run() {
        let pong = DispatchSemaphore(value: 0)
        while true {
            Thread.sleep(forTimeInterval: 0.25)
            let sent = Date()
            DispatchQueue.main.async { pong.signal() }
            if pong.wait(timeout: .now() + threshold) == .success { continue }

            // Stalled. A first look now, a second if it goes on, and the
            // report is finished when the main thread finally answers.
            let first = snapshot()
            let file = reportURL(for: sent)
            write(file, duration: nil, first: first, second: [])
            let top = first.first.map(describe) ?? "?"
            log.fault("Main thread stalled: no answer for \(threshold, format: .fixed(precision: 1)) s — \(top, privacy: .public) — \(file.path, privacy: .public)")
            var second: [UInt] = []
            if pong.wait(timeout: .now() + secondLook) != .success {
                second = snapshot()
                write(file, duration: nil, first: first, second: second)
                pong.wait()
            }
            let duration = Date().timeIntervalSince(sent)
            write(file, duration: duration, first: first, second: second)
            log.fault("Main thread answered after \(duration, format: .fixed(precision: 1)) s — \(file.path, privacy: .public)")
            ScreenshotMode.note("stall \(String(format: "%.1f", duration))s — \(top)")
            prune()
        }
    }

    // MARK: - Reading the main thread

    /// The main thread's frames, read while it is held still. Nothing in here
    /// may allocate or take a lock the main thread could be holding.
    private static func snapshot() -> [UInt] {
        var count = 0
        #if arch(arm64)
        var state = arm_thread_state64_t()
        var stateCount = mach_msg_type_number_t(MemoryLayout<arm_thread_state64_t>.size / MemoryLayout<natural_t>.size)
        let flavor = thread_state_flavor_t(ARM_THREAD_STATE64)
        #elseif arch(x86_64)
        var state = x86_thread_state64_t()
        var stateCount = mach_msg_type_number_t(MemoryLayout<x86_thread_state64_t>.size / MemoryLayout<natural_t>.size)
        let flavor = thread_state_flavor_t(x86_THREAD_STATE64)
        #endif
        guard thread_suspend(mainThread) == KERN_SUCCESS else { return [] }
        let got = withUnsafeMutablePointer(to: &state) { pointer in
            pointer.withMemoryRebound(to: natural_t.self, capacity: Int(stateCount)) {
                thread_get_state(mainThread, flavor, $0, &stateCount)
            }
        }
        if got == KERN_SUCCESS {
            #if arch(arm64)
            let pc = UInt(state.__pc)
            let lr = strip(UInt(state.__lr))
            var fp = UInt(state.__fp)
            #else
            let pc = UInt(state.__rip)
            let lr: UInt = 0
            var fp = UInt(state.__rbp)
            #endif
            frames[count] = pc; count += 1
            if lr != 0 { frames[count] = lr; count += 1 }
            // Up the chain of frame pointers, staying inside the main thread's
            // stack: each frame holds the caller's frame pointer, then the
            // return address into the caller.
            while count < maxFrames, fp >= stackLow, fp &+ 16 <= stackHigh, fp & 7 == 0 {
                let next = UnsafePointer<UInt>(bitPattern: fp)!.pointee
                let ret = strip(UnsafePointer<UInt>(bitPattern: fp &+ 8)!.pointee)
                guard ret != 0 else { break }
                frames[count] = ret; count += 1
                guard next > fp else { break }
                fp = next
            }
        }
        thread_resume(mainThread)
        return Array(UnsafeBufferPointer(start: frames, count: count))
    }

    /// A return address without pointer-authentication bits, should there be any.
    @inline(__always)
    private static func strip(_ address: UInt) -> UInt { address & 0x0000_7FFF_FFFF_FFFF }

    // MARK: - Naming the frames

    private typealias Demangle = @convention(c) (
        UnsafePointer<CChar>?, Int, UnsafeMutablePointer<CChar>?, UnsafeMutablePointer<Int>?, UInt32
    ) -> UnsafeMutablePointer<CChar>?

    private static let demangle: Demangle? = {
        // RTLD_DEFAULT
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "swift_demangle") else { return nil }
        return unsafeBitCast(symbol, to: Demangle.self)
    }()

    private static func readable(_ symbol: String) -> String {
        guard symbol.hasPrefix("$s") || symbol.hasPrefix("_$s") || symbol.hasPrefix("$S"), let demangle,
              let out = demangle(symbol, symbol.utf8.count, nil, nil, 0) else { return symbol }
        defer { free(out) }
        return String(cString: out)
    }

    private static func describe(_ address: UInt) -> String {
        let hex = "0x" + String(address, radix: 16)
        var info = Dl_info()
        guard dladdr(UnsafeRawPointer(bitPattern: address), &info) != 0 else { return hex }
        let image = info.dli_fname.map { URL(fileURLWithPath: String(cString: $0)).lastPathComponent } ?? "?"
        var line = "\(hex)  \(image) + \(address &- UInt(bitPattern: info.dli_fbase))"
        if let name = info.dli_sname {
            line += "  \(readable(String(cString: name))) + \(address &- UInt(bitPattern: info.dli_saddr))"
        }
        return line
    }

    // MARK: - The report

    private static func reportURL(for date: Date) -> URL {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return folder.appendingPathComponent("stall-\(f.string(from: date)).txt")
    }

    private static func write(_ file: URL, duration: TimeInterval?, first: [UInt], second: [UInt]) {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] ?? "?") (\(info["CFBundleVersion"] ?? "?"))"
        let load = "0x" + String(UInt(bitPattern: #dsohandle), radix: 16)
        var text = "Glassine \(version) — main thread stalled"
        text += duration.map { String(format: " for %.1f s", $0) } ?? " (still going when this was written)"
        text += "\n\(Date())\nGlassine loaded at \(load)\n"
        text += "Symbolicate an address: atos -o Glassine.app/Contents/MacOS/Glassine -l \(load) <address>\n"
        text += "\nMain thread after \(String(format: "%.0f", threshold)) s:\n"
        text += first.enumerated().map { "  \($0.offset)\t\(describe($0.element))" }.joined(separator: "\n")
        if !second.isEmpty {
            text += "\n\nMain thread after \(String(format: "%.0f", threshold + secondLook)) s:\n"
            text += second.enumerated().map { "  \($0.offset)\t\(describe($0.element))" }.joined(separator: "\n")
        }
        text += "\n"
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? text.write(to: file, atomically: true, encoding: .utf8)
    }

    /// The newest reports stay; a machine that stalls all day does not fill a disk.
    private static func prune() {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: folder.path) else { return }
        let reports = names.filter { $0.hasPrefix("stall-") && $0.hasSuffix(".txt") }.sorted()
        for name in reports.dropLast(maxReports) {
            try? fm.removeItem(at: folder.appendingPathComponent(name))
        }
    }
}
