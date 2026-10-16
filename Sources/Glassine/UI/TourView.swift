import AppKit
import SwiftUI

/// The tour: a first launch learns Glassine by using it.
///
/// Not a deck of cards over a dimmed window — a small prompt at the foot of
/// the page, and the page itself for a stage. Each step asks for one thing,
/// as keys: type a few words, ⌘1, ⌘2, Esc, ↩, ⌘↩, ⌘3, ⌥⇥, ⌘K, a look. The
/// keys are the real keys and do the real thing; the prompt watches the app
/// and, when the thing has happened, lights up, says in a line what it was,
/// and slides on to the next. Twelve steps, about a minute, and none of it
/// read so much as done — the way Superhuman once taught its keys as a
/// game. ⇥ skips a step, ⇧⇥ goes back, the ✕ ends it; Esc is never taken,
/// since Esc is one of the keys. Help → Tour of Glassine brings it back.
struct TourView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var tour = TourModel()

    private var theme: Theme { state.theme }
    private var step: TourStep { tour.step }
    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Nothing over the page: it stays the writer's. The prompt alone
            // takes the pointer.
            Color.clear.allowsHitTesting(false)
            card
                .padding(.bottom, 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            tour.state = state
            tour.begin()
        }
        .onDisappear { tour.end() }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in tour.check() }
    }

    // MARK: - The prompt

    private var card: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                dots
                Spacer()
                Button {
                    tour.finish()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(0.4)
                .help("End the tour (Help → Tour of Glassine brings it back)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ZStack {
                stepBody
                    .id(step)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: tour.forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: tour.forward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .clipped()
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: step)

            HStack(spacing: 10) {
                keyHint("⇥", "skip")
                keyHint("⇧⇥", "back")
                Spacer()
                Text("\(step.rawValue + 1) of \(TourStep.allCases.count)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .opacity(0.35)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .frame(width: step == .look ? 580 : 480)
        .background(
            ZStack {
                VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
                theme.tint.color.opacity(theme.isDark ? 0.5 : 0.62)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(tour.phase == .done ? theme.accent.color.opacity(0.55) : theme.text.color.opacity(theme.isDark ? 0.12 : 0.1), lineWidth: 1))
        .shadow(color: .black.opacity(theme.isDark ? 0.45 : 0.18), radius: 28, y: 10)
        .foregroundStyle(theme.text.color)
        .scaleEffect(tour.bump ? 1.025 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: tour.bump)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: step == .look)
        .animation(.easeOut(duration: 0.25), value: tour.phase)
    }

    private var dots: some View {
        HStack(spacing: 5) {
            ForEach(TourStep.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s == step ? theme.accent.color.opacity(0.9) : theme.text.color.opacity(s.rawValue < step.rawValue ? 0.4 : 0.18))
                    .frame(width: s == step ? 14 : 5, height: 5)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: step)
    }

    private func keyHint(_ keys: String, _ what: String) -> some View {
        HStack(spacing: 5) {
            Text(keys)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .padding(.horizontal, 4)
                .frame(height: 15)
                .background(RoundedRectangle(cornerRadius: 3.5).fill(theme.text.color.opacity(0.1)))
            Text(what).font(.system(size: 10.5))
        }
        .opacity(0.45)
    }

    // MARK: - The steps

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case .welcome: welcome
        case .look: lookStep
        case .done: done
        default: keyStep
        }
    }

    private var welcome: some View {
        HStack(alignment: .center, spacing: 18) {
            Group {
                if let image = SidebarView.wordmarkImage {
                    Image(nsImage: image).renderingMode(.template).resizable().interpolation(.high)
                        .scaledToFit().frame(height: 26).foregroundStyle(theme.text.color).opacity(0.9)
                } else {
                    Text("glassine").font(.system(size: 26, weight: .semibold, design: .rounded))
                }
            }
            .settle(0)
            VStack(alignment: .leading, spacing: 5) {
                Text("Ten keys. About a minute.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.headingColor.asColor)
                    .settle(1)
                Text("Nothing to read — each step asks for one key, and the page does the rest.")
                    .font(.system(size: 11.5))
                    .opacity(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .settle(2)
            }
            Spacer(minLength: 0)
            Button {
                tour.advance()
            } label: {
                HStack(spacing: 7) {
                    Text("Begin")
                    Keycap(label: "↩", theme: theme, lit: false, small: true)
                }
            }
            .buttonStyle(GlassButtonStyle(theme: theme, prominent: true))
            .settle(3)
        }
        .frame(height: 64)
    }

    private var keyStep: some View {
        HStack(alignment: .center, spacing: 18) {
            KeyRow(keys: step.keys, lit: tour.phase == .done, theme: theme, pulse: tour.phase == .waiting && !reduceMotion)
                .frame(minWidth: 96, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(tour.phase == .done ? step.praise : step.ask)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.headingColor.asColor)
                        .contentTransition(.opacity)
                    if tour.phase == .done {
                        Check(theme: theme)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
                Text(tour.phase == .done ? step.note : step.hint)
                    .font(.system(size: 11.5))
                    .opacity(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
            .animation(.easeOut(duration: 0.2), value: tour.phase)
            Spacer(minLength: 0)
        }
        .frame(height: 64)
    }

    /// The one choice in the tour: a look, picked by eye from a row of
    /// them. ← and → move along the row and the page changes under each;
    /// ↩ or a click keeps the one that is lit.
    private var lookStep: some View {
        let looks = Look.builtIns
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(tour.phase == .done ? "That's the look." : "Pick a look.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.headingColor.asColor)
                    .contentTransition(.opacity)
                if tour.phase == .done {
                    Check(theme: theme).transition(.scale(scale: 0.4).combined(with: .opacity))
                }
                Spacer()
                Text(tour.phase == .done
                     ? "Settings → Look has the rest: your own colours, the type, the caret."
                     : "← → to try them · ↩ to keep one")
                    .font(.system(size: 11))
                    .opacity(0.55)
                    .contentTransition(.opacity)
            }
            HStack(spacing: 8) {
                ForEach(Array(looks.enumerated()), id: \.element.id) { i, l in
                    LookMini(look: l, theme: state.themes.theme(id: l.themeID), backdrop: state.backdrops.preset(id: l.backdropID),
                             lit: tour.lookIndex == i)
                        .onTapGesture { tour.pickLook(i) }
                        .onHover { inside in if inside, tour.phase == .waiting { tour.previewLook(i) } }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: tour.lookIndex)
            .animation(.easeOut(duration: 0.2), value: tour.phase)
            HStack {
                Text(looks[min(tour.lookIndex, looks.count - 1)].name)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.accent.color)
                    .contentTransition(.opacity)
                Text(looks[min(tour.lookIndex, looks.count - 1)].blurb)
                    .font(.system(size: 11))
                    .opacity(0.5)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Spacer()
            }
            .animation(.easeOut(duration: 0.18), value: tour.lookIndex)
        }
    }

    private var done: some View {
        HStack(alignment: .center, spacing: 18) {
            Text("Write something.")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.headingColor.asColor)
                .settle(0)
            VStack(alignment: .leading, spacing: 4) {
                remember("⌘/", "every key, on one sheet")
                remember("⌘,", "Settings — ⌘Z there takes a change back")
                remember("Help", "Tour of Glassine brings this back")
            }
            .settle(1)
            Spacer(minLength: 0)
            Button {
                tour.finish()
            } label: {
                HStack(spacing: 7) {
                    Text("Done")
                    Keycap(label: "↩", theme: theme, lit: false, small: true)
                }
            }
            .buttonStyle(GlassButtonStyle(theme: theme, prominent: true))
            .settle(2)
        }
        .frame(height: 64)
    }

    private func remember(_ k: String, _ what: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(k).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(theme.accent.color)
                .frame(width: 30, alignment: .trailing)
            Text(what).font(.system(size: 11.5)).opacity(0.75)
        }
    }
}

// MARK: - The steps

enum TourStep: Int, CaseIterable {
    case welcome, type, gallery, timelapse, escape, open, review, today, pages, commands, look, done

    /// The keys, one keycap each; a word for the step that is not a key.
    var keys: [String] {
        switch self {
        case .type: return ["a", "b", "c"]
        case .gallery: return ["⌘", "1"]
        case .timelapse: return ["⌘", "2"]
        case .escape: return ["esc"]
        case .open: return ["↩"]
        case .review: return ["⌘", "↩"]
        case .today: return ["⌘", "3"]
        case .pages: return ["⌥", "⇥"]
        case .commands: return ["⌘", "K"]
        default: return []
        }
    }

    /// What to do, as few words as it takes.
    var ask: String {
        switch self {
        case .type: return "Type a few words."
        case .gallery: return "All Documents."
        case .timelapse: return "Timelapse."
        case .escape: return "Esc steps back."
        case .open: return "Return opens the lit card."
        case .review: return "Review."
        case .today: return "Today's note."
        case .pages: return "Hold ⌥, press Tab."
        case .commands: return "The command bar."
        default: return ""
        }
    }

    /// A line under the ask, before it is done.
    var hint: String {
        switch self {
        case .type: return "Anything. Watch the caret, and the sidebar."
        case .gallery: return "The whole library as a wall of cards."
        case .timelapse: return "Your days, receding into the window."
        case .escape: return "From the Timelapse, Esc goes to All Documents."
        case .open: return "↑ ↓ ← → move between the cards first, if you like."
        case .review: return "The page as a reader sees it, in any of fourteen styles."
        case .today: return "A note a day, in the Daily folder, made on first use."
        case .pages: return "The open pages fan out. Let go on one to open it."
        case .commands: return "Anything by name. Esc closes it when you are done."
        default: return ""
        }
    }

    /// Said once it has happened.
    var praise: String {
        switch self {
        case .type: return "Saved as you typed."
        case .gallery: return "Every page, as cards."
        case .timelapse: return "Day by day."
        case .escape: return "Back a level."
        case .open: return "And there it is."
        case .review: return "The finished page."
        case .today: return "Today's page."
        case .pages: return "Pages, no tabs."
        case .commands: return "Anything, by name."
        default: return ""
        }
    }

    /// The one thing worth knowing about it, after.
    var note: String {
        switch self {
        case .type: return "Every page is a Markdown file, named after its first line — in iCloud Drive, so it is already on your other Macs."
        case .gallery: return "⌘1 from anywhere. ⌘F searches everything you have written; the arrow keys walk the cards."
        case .timelapse: return "Scroll or press ↑ to walk back a day. ⇥ shows everything written each day, not only the notes."
        case .escape: return "Esc always goes up: Review → the page → All Documents ⇄ Timelapse."
        case .open: return "A click does the same. ⌘↩ on a card opens it in Review instead."
        case .review: return "⇥ walks the styles. Esc comes back to the editor. ⌘⇧↩ keeps the page beside the editor as you write."
        case .today: return "⌘3 or ⌘D, any day. Type @today, @yesterday or @tomorrow and a space in any line for a date."
        case .pages: return "A document stays open as a page until ⌘W closes it. ⌃⇥ works too; the pips in the footer show the pages."
        case .commands: return "Review styles, sorting, the modes, every look — ⌘K knows what makes sense where you are."
        default: return ""
        }
    }
}

// MARK: - The model

/// What the tour is up to: the step, whether its thing has happened, and
/// what it remembers from the start of the step to tell.
final class TourModel: ObservableObject {
    enum Phase { case waiting, done }

    @Published var step: TourStep = .welcome
    @Published var phase: Phase = .waiting
    @Published var forward = true
    /// A small pop of the card when a step lands.
    @Published var bump = false
    /// The look under the highlight on the look step.
    @Published var lookIndex = 0

    weak var state: AppState?
    private var monitor: Any?
    private var advanceWork: DispatchWorkItem?
    // What the step started from.
    private var startChars = 0
    private var startDoc: String?
    private var sawCarousel = false
    private var sawBar = false

    func begin() {
        if let s = UserDefaults.standard.string(forKey: "glassine.tourStep").flatMap(Int.init), let st = TourStep(rawValue: min(max(0, s), TourStep.allCases.count - 1)) {
            step = st
        }
        install()
        prepare(step)
    }

    func end() {
        uninstall()
        advanceWork?.cancel()
    }

    /// The keys the tour owns: ⇥ skips, ⇧⇥ goes back; ↩ begins, finishes
    /// and keeps a look; ← → walk the looks. Everything else — Esc above
    /// all — is the app's, and the tour only watches what it does.
    private func install() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let state = self.state, state.showingTour, !state.overlayUp else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function])
            switch event.keyCode {
            case 48 where flags.isEmpty:          // ⇥
                self.skip()
                return nil
            case 48 where flags == .shift:        // ⇧⇥
                self.back()
                return nil
            case 36, 76:                          // ↩
                guard flags.isEmpty else { return event }
                switch self.step {
                case .welcome: self.advance(); return nil
                case .done: self.finish(); return nil
                case .look where self.phase == .waiting: self.pickLook(self.lookIndex); return nil
                default: return event
                }
            case 123 where self.step == .look && flags.isEmpty:   // ←
                self.previewLook(max(0, self.lookIndex - 1)); return nil
            case 124 where self.step == .look && flags.isEmpty:   // →
                self.previewLook(min(Look.builtIns.count - 1, self.lookIndex + 1)); return nil
            default:
                return event
            }
        }
    }

    private func uninstall() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    // MARK: Moving along

    func advance() {
        guard let next = TourStep(rawValue: step.rawValue + 1) else { finish(); return }
        advanceWork?.cancel()
        forward = true
        phase = .waiting
        step = next
        prepare(next)
    }

    func back() {
        guard let prev = TourStep(rawValue: step.rawValue - 1) else { return }
        advanceWork?.cancel()
        forward = false
        phase = .waiting
        step = prev
        prepare(prev)
    }

    func skip() {
        if step == .done { finish() } else { advance() }
    }

    func finish() {
        guard let state else { return }
        state.settings.data.tourSeen = true
        withAnimation(.easeOut(duration: 0.25)) { state.showingTour = false }
    }

    /// The step's thing has happened: the keys light, the card pops, the
    /// line says what it was, and a beat later the next step slides in.
    private func land() {
        guard phase == .waiting else { return }
        phase = .done
        bump = true
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in self?.bump = false }
        let work = DispatchWorkItem { [weak self] in self?.advance() }
        advanceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (step == .look ? 1.6 : 2.4), execute: work)
    }

    // MARK: Each step's start and its test

    /// The app put where the step can be done from, and what the step
    /// starts from remembered.
    private func prepare(_ s: TourStep) {
        guard let state else { return }
        sawCarousel = false
        sawBar = false
        switch s {
        case .welcome, .done:
            break
        case .type:
            // A fresh page to type on — the Welcome page a first launch opens
            // on is for reading — unless a page of the writer's is open already.
            let welcome = state.document?.title == "Welcome to Glassine"
            if state.document == nil || welcome { state.newDocument() }
            state.reviewMode = false
            state.showingGallery = false
            state.showingDaily = false
            startChars = state.document?.characterCount ?? 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if let tv = GlassineTextView.current { tv.window?.makeFirstResponder(tv) }
            }
        case .gallery:
            if state.document == nil { state.newDocument() }
            if state.galleryOnScreen || state.showingDaily { state.showingDaily = false; state.showingGallery = false }
        case .timelapse:
            if state.showingDaily { state.showingDaily = false }
        case .escape:
            if !state.showingDaily { state.showDaily() }
        case .open:
            if state.document == nil { state.newDocument() }
            if !state.galleryOnScreen { state.showingDaily = false; state.showingGallery = true }
            startDoc = nil
        case .review:
            if state.document == nil { state.newDocument() }
            state.showingGallery = false
            state.showingDaily = false
            state.reviewMode = false
        case .today:
            if state.todaysNoteOnScreen {
                if state.openPages.count > 1 { state.switchToPreviousPage() } else { state.showingGallery = true }
            }
        case .pages:
            // Two pages at least, or there is nothing to fan: on past it.
            let pages = state.openPages.filter { state.library.document(withID: $0) != nil }
            if !state.keepsPagesOpen || pages.count < 2 {
                DispatchQueue.main.async { [weak self] in self?.advance() }
                return
            }
            state.showingGallery = false
            state.showingDaily = false
            startDoc = state.document?.relativePath
        case .commands:
            if state.showingCommandBar { state.showingCommandBar = false }
        case .look:
            lookIndex = Look.builtIns.firstIndex { $0.id == state.currentLook?.id } ?? 0
        }
    }

    /// Ten times a second: has the step's thing happened?
    func check() {
        guard let state, phase == .waiting else { return }
        switch step {
        case .welcome, .done, .look:
            return
        case .type:
            if (state.document?.characterCount ?? 0) - startChars >= 6 { land() }
        case .gallery:
            if state.galleryOnScreen { land() }
        case .timelapse:
            if state.showingDaily { land() }
        case .escape:
            if state.galleryOnScreen { land() }
        case .open:
            if !state.galleryOnScreen, !state.showingDaily, state.document != nil { land() }
        case .review:
            if state.inReview { land() }
        case .today:
            if state.todaysNoteOnScreen { land() }
        case .pages:
            if state.carousel != nil { sawCarousel = true }
            if sawCarousel, state.carousel == nil, state.document?.relativePath != startDoc { land() }
        case .commands:
            if state.showingCommandBar { sawBar = true }
            if sawBar, !state.showingCommandBar { land() }
        }
    }

    // MARK: The look step

    /// The look under the pointer or the arrows goes on at once, to be seen.
    func previewLook(_ i: Int) {
        guard let state, phase == .waiting, i >= 0, i < Look.builtIns.count else { return }
        lookIndex = i
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { state.applyLook(Look.builtIns[i]) }
    }

    func pickLook(_ i: Int) {
        guard phase == .waiting else { return }
        previewLook(i)
        land()
    }
}

// MARK: - Pieces

/// A key as a keycap: the symbol on a small plate with a lit top edge. Lit,
/// it takes the accent — the step is done. Pulsing, it presses itself every
/// few seconds, the way a hint should: seen, never read.
struct Keycap: View {
    let label: String
    let theme: Theme
    var lit: Bool
    var small = false
    var pressed = false

    private var wide: Bool { label.count > 1 && !["⌘", "⌥", "⇥", "⌃", "↩"].contains(label) }

    var body: some View {
        Text(label)
            .font(.system(size: small ? 10 : (label.count > 1 ? 12 : 15), weight: .medium, design: .rounded))
            .foregroundStyle(lit ? theme.accent.color : theme.text.color.opacity(0.85))
            .frame(minWidth: small ? 18 : 34)
            .frame(height: small ? 18 : 34)
            .padding(.horizontal, wide ? 9 : 0)
            .background(
                RoundedRectangle(cornerRadius: small ? 4 : 8, style: .continuous)
                    .fill(lit ? theme.accent.color.opacity(0.22) : theme.text.color.opacity(pressed ? 0.16 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: small ? 4 : 8, style: .continuous)
                    .strokeBorder(lit ? theme.accent.color.opacity(0.7) : theme.text.color.opacity(0.14), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                // The lit top edge of a key.
                RoundedRectangle(cornerRadius: small ? 4 : 8, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(theme.isDark ? 0.09 : 0.5), .clear], startPoint: .top, endPoint: .center))
                    .allowsHitTesting(false)
            }
            .offset(y: pressed ? 1.5 : 0)
            .scaleEffect(pressed ? 0.95 : 1)
            .shadow(color: .black.opacity(pressed || lit ? 0 : (theme.isDark ? 0.3 : 0.1)), radius: 1, y: 1.5)
    }
}

/// A step's keys in a row. While the step waits, the keys press themselves
/// in turn every few seconds; when it lands they light together and pop.
struct KeyRow: View {
    let keys: [String]
    let lit: Bool
    let theme: Theme
    var pulse: Bool
    @State private var pressing: Int? = nil
    @State private var popped = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(keys.enumerated()), id: \.offset) { i, k in
                Keycap(label: k, theme: theme, lit: lit, pressed: pressing == i)
                    .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressing)
            }
        }
        .scaleEffect(popped ? 1.08 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.5), value: popped)
        .animation(.easeOut(duration: 0.18), value: lit)
        .onChange(of: lit) { _, now in
            guard now else { return }
            popped = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { popped = false }
        }
        .task(id: pulse) {
            guard pulse else { return }
            // A first press soon after the step comes up, then every so often.
            try? await Task.sleep(for: .seconds(1.1))
            while !Task.isCancelled && pulse {
                for i in keys.indices {
                    pressing = i
                    try? await Task.sleep(for: .milliseconds(130))
                    if Task.isCancelled { return }
                }
                try? await Task.sleep(for: .milliseconds(90))
                pressing = nil
                try? await Task.sleep(for: .seconds(2.6))
            }
        }
    }
}

/// A check mark drawn in, in the accent.
struct Check: View {
    let theme: Theme
    @State private var drawn: CGFloat = 0

    var body: some View {
        ZStack {
            Circle().fill(theme.accent.color.opacity(0.18))
            Path { p in
                p.move(to: CGPoint(x: 5, y: 9.5))
                p.addLine(to: CGPoint(x: 8, y: 12.5))
                p.addLine(to: CGPoint(x: 13.5, y: 6))
            }
            .trim(from: 0, to: drawn)
            .stroke(theme.accent.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 18, height: 18)
        .onAppear {
            withAnimation(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .easeOut(duration: 0.32).delay(0.08)) { drawn = 1 }
        }
    }
}

/// A look in small, for the tour's row: the folds, and a chip of the page.
struct LookMini: View {
    let look: Look
    let theme: Theme
    let backdrop: BackdropPreset
    let lit: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            if backdrop.isDesktop {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(LinearGradient(colors: [Color.primary.opacity(0.12), Color.primary.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
            } else {
                BackdropSwatch(preset: backdrop, theme: theme)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Aa").font(.system(size: 9, weight: .semibold, design: .serif)).foregroundStyle(Color(nsColor: theme.headingColor))
                    Spacer(minLength: 0)
                    Circle().fill(theme.accent.color).frame(width: 4, height: 4)
                }
                Capsule().fill(theme.text.color.opacity(0.55)).frame(width: 22, height: 2)
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(theme.tint.color.opacity(backdrop.isDesktop ? theme.tintOpacity : 0.8)))
            .padding(.horizontal, 7)
            .padding(.bottom, 4)
        }
        .frame(width: 60, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(lit ? theme.accent.color : Color.primary.opacity(0.14), lineWidth: lit ? 2 : 1))
        .scaleEffect(lit ? 1.08 : 1)
        .contentShape(Rectangle())
        .help(look.name)
    }
}

/// A row settling into place a beat after the one before it.
private struct Settle: ViewModifier {
    let order: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 8)
            .onAppear {
                let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                withAnimation(reduce ? .none : .spring(response: 0.5, dampingFraction: 0.85).delay(0.1 + Double(order) * 0.07)) { shown = true }
            }
    }
}

private extension View {
    func settle(_ order: Int) -> some View { modifier(Settle(order: order)) }
}
