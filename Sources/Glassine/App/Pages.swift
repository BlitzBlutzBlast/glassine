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
    /// The card the row is centred on. The keys move it with the highlight;
    /// the pointer moves the highlight alone, so nothing slides under a
    /// resting hand — a row that re-centred on hover ran away under the
    /// pointer, card after card.
    var anchor: Int
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
            closeLooseDocument()   // saves what is unsaved, off the main thread
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
            closeLooseDocument()
            showingGallery = true
        }
    }

    /// File → Close Other Pages (⌥⌘W): every page but the one on screen
    /// closes, so the stack is one page again. From a pip's menu, every page
    /// but that one.
    func closeOtherPages(keeping id: String? = nil) {
        let keep = id ?? document?.relativePath
        guard let keep else { return }
        let pages = settings.data.openPages
        guard pages.count > 1 || pages.first != keep else { return }
        settings.data.openPages = pages.contains(keep) ? [keep] : []
        if document?.relativePath != keep { switchToPage(keep) }
        if let c = carousel, c.order.count > 1 { carousel = nil }
    }

    /// File → Close All Pages (⌥⇧⌘W): the stack empties and All Documents
    /// comes up, the way closing the last page does.
    func closeAllPages() {
        guard !settings.data.openPages.isEmpty || document != nil else { return }
        settings.data.openPages = []
        carousel = nil
        closeLooseDocument()
        showingGallery = true
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
            c.anchor = c.index
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
        let start = backward ? order.count - 1 : 1
        ScreenshotMode.note("carousel up with \(order.count) pages")
        carousel = PageCarousel(order: order, index: start, anchor: start)
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
        c.anchor = min(c.anchor, c.order.count - 1)
        carousel = c
    }

    /// A card clicked: that page, at once.
    func pickFromCarousel(_ id: String) {
        guard carousel != nil else { return }
        carousel = nil
        ScreenshotMode.note("carousel pick \(id)")
        switchToPage(id)
    }

    /// The × on a card clicked: that page closes and the cards close up;
    /// the carousel stays, so several can go in a row. The last card left
    /// cannot be closed from here — ⌘W does that, and leaves All Documents.
    func closeFromCarousel(_ id: String) {
        guard var c = carousel, c.order.count > 1, let at = c.order.firstIndex(of: id) else { return }
        c.order.remove(at: at)
        var pages = settings.data.openPages
        pages.removeAll { $0 == id }
        settings.data.openPages = pages
        c.index = min(c.index > at ? c.index - 1 : c.index, c.order.count - 1)
        c.anchor = min(c.anchor > at ? c.anchor - 1 : c.anchor, c.order.count - 1)
        carousel = c
        ScreenshotMode.note("carousel close \(id)")
    }

    /// The pointer over a card: the highlight follows it, so letting go of
    /// the modifier opens the page under the pointer.
    func hoverCarousel(_ index: Int) {
        guard var c = carousel, index >= 0, index < c.order.count, c.index != index else { return }
        c.index = index
        carousel = c
    }

    /// A digit while the carousel is up: that card, counted from the left.
    func jumpCarousel(to index: Int) {
        guard var c = carousel, index >= 0, index < c.order.count else { return }
        c.index = index
        c.anchor = index
        carousel = c
    }

    /// Where the fanned cards are, in the window's own coordinates (the root
    /// space, top-left origin), reported by the carousel as it lays out. A
    /// click is matched against these by hand: with ⌃ held a click arrives
    /// as a right click, which no tap gesture hears.
    var carouselCardFrames: [String: CGRect] {
        get { carouselFramesBox.frames }
        set { carouselFramesBox.frames = newValue }
    }

    /// Where each card's × is, the same way.
    var carouselCloseFrames: [String: CGRect] {
        get { carouselFramesBox.closes }
        set { carouselFramesBox.closes = newValue }
    }

    /// The keys: ⌥Tab or ⌃Tab anywhere in the app (⇧ for backwards); ⌫ and
    /// Esc while the carousel is up; ← → and the digits move the highlight;
    /// ↩ or a click — either button — opens; the modifier let go opens the
    /// page. A local monitor, so the editor never sees the Tab.
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
                    guard self.keepsPagesOpen, self.pendingPrompt == nil, !self.showingSettings, !self.showingShortcuts,
                          !self.showingCommandBar else { return event }
                    if self.carousel == nil { self.carouselModifier = held }
                    self.stepCarousel(backward: flags.contains(.shift))
                    return nil
                }
            }
            if self.carousel != nil {
                switch event.keyCode {
                case 53: self.cancelCarousel(); return nil          // Esc
                case 51, 117: self.closeHighlightedPage(); return nil   // ⌫, ⌦
                case 123, 126: self.stepCarousel(backward: true); return nil   // ← ↑
                case 124, 125: self.stepCarousel(backward: false); return nil  // → ↓
                case 36, 76, 49: self.commitCarousel(); return nil   // ↩, enter, space
                default:
                    // 1–9: straight to that card.
                    if let ch = event.charactersIgnoringModifiers?.first, let n = ch.wholeNumberValue, n >= 1 {
                        self.jumpCarousel(to: n - 1)
                    }
                    return nil
                }
            }
            return event
        }
        // The mouse while the cards are fanned: a press on a card opens it —
        // the right button too, since ⌃-click is one — a press beside them
        // leaves things as they were, and a sideways scroll steps along.
        pageMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .scrollWheel]) { [weak self] event in
            guard let self, self.carousel != nil, let window = event.window, AppDelegate.isMainWindow(window),
                  let content = window.contentView else { return event }
            if event.type == .scrollWheel {
                let dx = event.scrollingDeltaX, dy = event.scrollingDeltaY
                let delta = abs(dx) >= abs(dy) ? dx : dy
                self.carouselScroll += Double(delta)
                if abs(self.carouselScroll) >= 40 {
                    self.stepCarousel(backward: self.carouselScroll > 0)
                    self.carouselScroll = 0
                }
                if event.phase == .ended || event.momentumPhase == .ended { self.carouselScroll = 0 }
                return nil
            }
            let p = event.locationInWindow
            let point = CGPoint(x: p.x, y: content.bounds.height - p.y)
            ScreenshotMode.note("carousel click at \(point)")
            if let close = self.carouselCloseFrames.first(where: { $0.value.contains(point) }) {
                self.closeFromCarousel(close.key)
            } else if let hit = self.carouselCardFrames.first(where: { $0.value.contains(point) }) {
                self.pickFromCarousel(hit.key)
            } else {
                self.cancelCarousel()
            }
            return nil
        }
    }
}

/// The card frames, in a box so the extension can keep them without a stored property.
final class CarouselFrames {
    var frames: [String: CGRect] = [:]
    var closes: [String: CGRect] = [:]
}
