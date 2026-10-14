import AppKit
import SwiftUI

/// Open pages.
///
/// A document opened stays open, as a page, until it is closed (⌘W): the
/// pages are a stack with the one being written on top, kept between
/// launches. There is no row of tabs — the window stays as quiet as it was.
/// Hold ⌥ and press Tab and the page steps back, and the open pages fan out
/// across it as cards in the order they were last used, the way ⌘Tab shows
/// apps: Tab steps along them, ⇧Tab back, ⌫ closes the one under the
/// highlight, Esc leaves things as they were, and letting go of ⌥ opens the
/// highlighted page — so a tap of ⌥Tab flips to the page before this one.
/// The page slides aside as the other comes in. A quiet row of pips in the
/// footer shows how many pages are open and which; a click goes there.
/// Settings → Library → Pages turns the stack off, for one page at a time.
struct PageCarousel: Equatable {
    /// The pages as the carousel shows them: the one on top first.
    var order: [String]
    /// The card under the highlight.
    var index: Int
}

extension AppState {

    // MARK: - The stack

    /// Whether documents stay open as pages (Settings → Library → Pages).
    var keepsPagesOpen: Bool { settings.data.keepPagesOpen }

    /// The open pages, most recently used first. The document being written
    /// is the first, when it is one of the library's.
    var openPages: [String] { settings.data.openPages }

    /// A document opened goes to the top of the stack — or is the stack, when
    /// pages are not kept.
    func notePageOpened(_ id: String) {
        var pages = settings.data.openPages
        pages.removeAll { $0 == id }
        pages.insert(id, at: 0)
        if !keepsPagesOpen { pages = [id] }
        if pages.count > 40 { pages.removeLast(pages.count - 40) }
        if pages != settings.data.openPages { settings.data.openPages = pages }
    }

    /// Pages whose documents are gone are dropped (at launch, after a scan).
    func prunePages() {
        let kept = settings.data.openPages.filter { library.document(withID: $0) != nil }
        if kept != settings.data.openPages { settings.data.openPages = kept }
    }

    /// ⌘W: the page closes and the one under it comes up; the last page closed
    /// leaves All Documents. A document from elsewhere simply closes.
    func closeCurrentPage() {
        guard let doc = document else { return }
        if doc.isLoose {
            doc.saveNow()
            closeLooseDocument()
            return
        }
        closePage(doc.relativePath)
    }

    func closePage(_ id: String) {
        var pages = settings.data.openPages
        pages.removeAll { $0 == id }
        settings.data.openPages = pages
        guard document?.relativePath == id else { return }
        if let next = pages.first, let ref = library.document(withID: next) {
            pageSlide = -1
            open(ref)
        } else {
            document?.saveNow()
            closeLooseDocument()
            showingGallery = true
        }
    }

    /// Switches to a page already open, the page sliding aside: from the
    /// right when the page is further down the stack, from the left otherwise.
    func switchToPage(_ id: String) {
        guard let ref = library.document(withID: id) else { return }
        if document?.relativePath == id { showingGallery = false; showingDaily = false; return }
        let from = openPages.firstIndex(of: document?.relativePath ?? "") ?? 0
        let to = openPages.firstIndex(of: id) ?? openPages.count
        pageSlide = to >= from ? 1 : -1
        open(ref)
    }

    /// The page before this one — a tap of ⌥Tab, or View → Previous Page.
    func switchToPreviousPage() {
        guard openPages.count > 1 else { return }
        let current = document?.relativePath
        let target = openPages.first { $0 != current } ?? openPages[0]
        switchToPage(target)
    }

    // MARK: - The carousel

    /// ⌥Tab or ⌃Tab: the carousel comes up with the page before this one under
    /// the highlight; each Tab while the modifier is held steps along, ⇧Tab
    /// steps back.
    func stepCarousel(backward: Bool) {
        if var c = carousel {
            guard !c.order.isEmpty else { return }
            c.index = (c.index + (backward ? -1 : 1) + c.order.count) % c.order.count
            carousel = c
            return
        }
        let order = openPages.filter { library.document(withID: $0) != nil }
        guard order.count > 1 else {
            // One page is nothing to step through; a nudge says so.
            carouselNudge += 1
            return
        }
        showingCommandBar = false
        carousel = PageCarousel(order: order, index: backward ? order.count - 1 : 1)
    }

    /// The modifier let go: the highlighted page opens.
    func commitCarousel() {
        guard let c = carousel else { return }
        carousel = nil
        guard c.index < c.order.count else { return }
        switchToPage(c.order[c.index])
    }

    /// Esc with the carousel up: nothing changes — unless a page closed from
    /// it was the one on screen, in which case the next one comes up.
    func cancelCarousel() {
        guard carousel != nil else { return }
        carousel = nil
        if let id = document?.relativePath, !openPages.contains(id), !openPages.isEmpty {
            switchToPage(openPages[0])
        }
    }

    /// ⌫ with the carousel up: the page under the highlight closes.
    func closeHighlightedPage() {
        guard var c = carousel, c.order.count > 1 else { return }
        let id = c.order.remove(at: c.index)
        var pages = settings.data.openPages
        pages.removeAll { $0 == id }
        settings.data.openPages = pages
        c.index = min(c.index, c.order.count - 1)
        carousel = c
    }

    /// A card clicked: that page, at once.
    func pickFromCarousel(_ id: String) {
        guard carousel != nil else { return }
        carousel = nil
        switchToPage(id)
    }

    /// The keys: ⌥Tab or ⌃Tab anywhere in the app (⇧ for backwards); ⌫ and
    /// Esc while the carousel is up; the modifier let go opens the page. A
    /// local monitor, so the editor never sees the Tab.
    func installPageKeys() {
        pageKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            if event.type == .flagsChanged {
                // Whichever modifier brought the carousel up, letting it go commits.
                if self.carousel != nil, let held = self.carouselModifier, !event.modifierFlags.contains(held) {
                    self.commitCarousel()
                }
                return event
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Tab with ⌥ or ⌃ (and ⇧, for backwards), nothing else.
            if event.keyCode == 48, !flags.contains(.command) {
                let held: NSEvent.ModifierFlags? = flags.contains(.option) && !flags.contains(.control) ? .option
                    : flags.contains(.control) && !flags.contains(.option) ? .control : nil
                if let held {
                    guard self.keepsPagesOpen, self.pendingPrompt == nil else { return event }
                    if self.carousel == nil { self.carouselModifier = held }
                    self.stepCarousel(backward: flags.contains(.shift))
                    return nil
                }
            }
            if self.carousel != nil {
                switch event.keyCode {
                case 53: self.cancelCarousel(); return nil          // Esc
                case 51, 117: self.closeHighlightedPage(); return nil   // ⌫, ⌦
                case 123: self.stepCarousel(backward: true); return nil   // ←
                case 124: self.stepCarousel(backward: false); return nil  // →
                case 36: self.commitCarousel(); return nil           // ↩
                default: return nil
                }
            }
            return event
        }
    }
}
