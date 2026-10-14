import SwiftUI

/// The tour: a first launch's walk through what Glassine is and the handful
/// of choices worth making before writing — the backdrop, the theme, the
/// type, the caret, the modes, the pages — each made on the spot and seen
/// at once on the page behind the card. Eight short steps, each sliding in
/// as the last slides out, the rows of each settling in one after another.
/// Help → Tour of Glassine brings it back; everything in it is in Settings.
struct TourView: View {
    @EnvironmentObject var state: AppState
    @State private var step = 0
    @State private var forward = true
    @State private var monitor: Any?

    private var theme: Theme { state.theme }
    private var form: SettingsForm { SettingsForm(state: state) }
    private var data: SettingsData { state.settings.data }
    static let steps = 8

    var body: some View {
        ZStack {
            Color.black.opacity(theme.isDark ? 0.28 : 0.14)
                .ignoresSafeArea()
                .onTapGesture { }
            card
        }
        .onAppear {
            if let s = UserDefaults.standard.string(forKey: "glassine.tourStep").flatMap(Int.init) { step = min(max(0, s), Self.steps - 1) }
            install()
        }
        .onDisappear { uninstall() }
    }

    // MARK: - The card

    private var card: some View {
        VStack(spacing: 0) {
            ZStack {
                page(step)
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: step)
            footer
        }
        .padding(28)
        .frame(width: 700, height: 540)
        .background(
            ZStack {
                VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
                theme.tint.color.opacity(theme.isDark ? 0.5 : 0.6)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(theme.text.color.opacity(theme.isDark ? 0.12 : 0.1), lineWidth: 1))
        .shadow(color: .black.opacity(theme.isDark ? 0.45 : 0.18), radius: 30, y: 12)
        .foregroundStyle(theme.text.color)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if step == 0 {
                Button("Skip the tour") { finish() }
                    .buttonStyle(GlassButtonStyle(theme: theme))
            } else {
                Button("Back") { go(-1) }
                    .buttonStyle(GlassButtonStyle(theme: theme))
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<Self.steps, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? theme.accent.color.opacity(0.9) : theme.text.color.opacity(0.22))
                        .frame(width: i == step ? 16 : 6, height: 6)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: step)
            Spacer()
            Button(step == Self.steps - 1 ? "Write something" : "Next") { go(1) }
                .buttonStyle(GlassButtonStyle(theme: theme, prominent: true))
        }
        .padding(.top, 14)
    }

    private func go(_ by: Int) {
        if by > 0, step == Self.steps - 1 { finish(); return }
        let next = step + by
        guard next >= 0, next < Self.steps else { return }
        forward = by > 0
        step = next
    }

    private func finish() {
        state.settings.data.tourSeen = true
        withAnimation(.easeOut(duration: 0.2)) { state.showingTour = false }
    }

    /// Return and → go on, ← goes back, Esc leaves; a local monitor, since the
    /// card has no field to hold the keyboard.
    private func install() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard state.showingTour else { return event }
            switch event.keyCode {
            case 36, 124: go(1); return nil     // ↩, →
            case 123: go(-1); return nil        // ←
            case 53: finish(); return nil       // Esc
            default: return event
            }
        }
    }

    private func uninstall() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    // MARK: - The pages

    @ViewBuilder
    private func page(_ i: Int) -> some View {
        switch i {
        case 0: welcome
        case 1: backdrop
        case 2: themes
        case 3: type
        case 4: caret
        case 5: modes
        case 6: pages
        default: done
        }
    }

    private func heading(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.headingColor.asColor)
            Text(sub)
                .font(.system(size: 13))
                .opacity(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 18)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let image = Bundle.main.image(forResource: "wordmark") {
                    Image(nsImage: image).renderingMode(.template).resizable().interpolation(.high)
                        .scaledToFit().frame(height: 34).foregroundStyle(theme.text.color).opacity(0.85)
                } else {
                    Text("glassine").font(.system(size: 34, weight: .semibold, design: .rounded))
                }
            }
            .settle(0)
            Text("A writing app that stays out of the sentence.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.headingColor.asColor)
                .padding(.top, 14)
                .settle(1)
            VStack(alignment: .leading, spacing: 12) {
                idea("Plain files.", "Every document is a Markdown file in a folder you own — iCloud Drive, by default. Readable by anything, now and in twenty years.", 2)
                idea("Marks that step back.", "The syntax stays on the page, dimmed, so what you see is what is in the file. Hide it when you'd rather not see it; the file is the same.", 3)
                idea("Glass.", "The page is translucent. Behind it is the desktop, or folds of colour of your own. The chrome goes quiet while you type.", 4)
                idea("Nothing that tries too hard.", "A caret that glides, a few things that move when they should, and no feature for its own sake.", 5)
            }
            .padding(.top, 20)
            Text("A minute of choices follows. Every one of them is yours to change later, in Settings (⌘,), where ⌘Z takes a change back.")
                .font(.system(size: 12))
                .opacity(0.55)
                .padding(.top, 22)
                .fixedSize(horizontal: false, vertical: true)
                .settle(6)
        }
    }

    private func idea(_ title: String, _ body: String, _ n: Int) -> some View {
        (Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.headingColor.asColor)
         + Text(" " + body).font(.system(size: 13)))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(0.9)
            .settle(n)
    }

    private var backdrop: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("Behind the glass", "What the page floats over. The desktop, blurred — or folds of colour that live inside the window, so the look doesn't depend on the wallpaper. Watch the page as you pick.")
                .settle(0)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                ForEach(Array(BackdropPreset.builtIns.enumerated()), id: \.element.id) { n, b in
                    BackdropTile(preset: b, theme: theme, selected: data.backdrop == b.id) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { state.settings.data.backdrop = b.id }
                    }
                    .settle(1 + n / 3)
                }
            }
            HStack(spacing: 18) {
                row("Drift", "The folds move, slowly.") { GlassToggle(theme: theme, isOn: form.binding(\.backdropDrift)) }
                row("Frost", nil) { GlassSlider(theme: theme, value: form.binding(\.backdropFrost), range: 0...1, step: 0.05, format: "%.0f%%", scale: 100) }
            }
            .padding(.top, 22)
            .settle(5)
        }
    }

    private var themes: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("A theme", "The colours of the page: the text, the headings, the accent the marks and the caret take. Dark ones for dark rooms; Paper for a light one.")
                .settle(0)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(Array(Theme.builtIns.enumerated()), id: \.element.id) { n, t in
                    ThemeTile(theme: t, selected: state.theme.id == t.id) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { state.chooseTheme(t.id) }
                    }
                    .settle(1 + n / 3)
                }
            }
            row("Follow the Mac's appearance", "A dark theme at night and a light one by day, as the system switches.") {
                GlassToggle(theme: theme, isOn: Binding(
                    get: { data.appearanceMode == .system },
                    set: { state.settings.data.appearanceMode = $0 ? .system : .fixed }))
            }
            .padding(.top, 22)
            .settle(5)
        }
    }

    private var type: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("The type", "What the writing is set in. The page behind changes as you choose; the Type section of Settings has every face on the Mac, and the spacing.")
                .settle(0)
            TypeSpecimen(config: state.styleConfig)
                .frame(height: 160)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.tint.color.opacity(theme.isDark ? 0.5 : 0.6)))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(theme.text.color.opacity(0.08), lineWidth: 1))
                .settle(1)
            VStack(alignment: .leading, spacing: 12) {
                row("Face", nil) {
                    PillPicker(theme: theme, selection: Binding(
                        get: { Self.faces.contains { $0.id == data.fontFamily } ? data.fontFamily : "other" },
                        set: { if $0 != "other" { state.settings.data.fontFamily = $0 } }),
                        options: Self.faces.map(\.id) + (Self.faces.contains { $0.id == data.fontFamily } ? [] : ["other"]),
                        label: { id in Self.faces.first { $0.id == id }?.label ?? data.fontFamily })
                }
                row("Size", nil) { GlassSlider(theme: theme, value: form.binding(\.fontSize), range: 12...24, step: 1, format: "%.0f pt") }
                row("Centred headings", nil) { GlassToggle(theme: theme, isOn: form.binding(\.centerHeadings)) }
            }
            .padding(.top, 18)
            .settle(2)
        }
    }

    private static let faces: [(id: String, label: String)] = [
        ("Helvetica Neue", "Helvetica"), (SystemFontChoice.serif, "New York"), (SystemFontChoice.sans, "San Francisco"),
        ("Georgia", "Georgia"), (SystemFontChoice.mono, "SF Mono"),
    ]

    private var caret: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("The caret", "It glides from where it was to where it is, so the eye can follow it. Eight shapes; pick the one you'd like to look at all day. Leave it a while and it does a small trick.")
                .settle(0)
            CaretSpecimen(config: state.styleConfig)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.tint.color.opacity(theme.isDark ? 0.5 : 0.6)))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(theme.text.color.opacity(0.08), lineWidth: 1))
                .settle(1)
            CaretShapePicker(shape: form.binding(\.caretShape), color: Color(nsColor: theme.caretColor), accent: theme.accent.color)
                .padding(.top, 16)
                .settle(2)
            HStack(spacing: 18) {
                row("Glides", nil) { GlassToggle(theme: theme, isOn: form.binding(\.smoothCaret)) }
                row("Glide time", nil) { GlassSlider(theme: theme, value: form.binding(\.caretSpeed), range: 0.04...0.5, step: 0.01, format: "%.0f ms", scale: 1000) }
                row("Tricks when idle", nil) { GlassToggle(theme: theme, isOn: form.binding(\.caretTricks)) }
            }
            .padding(.top, 18)
            .settle(3)
        }
    }

    private var modes: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("How the page behaves", "Three things the editor can do for you while you write. All three are a key away, and in the View menu.")
                .settle(0)
            VStack(alignment: .leading, spacing: 14) {
                big("Typewriter scrolling", "The line you are writing stays at the middle of the window; the page moves instead of your eyes.", "⌃⌘T", \.typewriterMode, 1)
                big("Focus mode", "Everything but the paragraph you are in steps back, dimmed. The rest of the page is still there when you want it.", "⌃⌘F", \.focusMode, 2)
                big("Hide the Markdown", "The marks leave the page — except in the sentence being written, which shows its syntax so it can be edited as written.", "⌃⌘M", \.hideSyntax, 3)
            }
        }
    }

    private func big(_ title: String, _ caption: String, _ key: String, _ kp: WritableKeyPath<SettingsData, Bool>, _ n: Int) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(theme.headingColor.asColor)
                    Text(key).font(.system(size: 10.5, weight: .medium, design: .rounded)).opacity(0.45)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(theme.text.color.opacity(0.07)))
                }
                Text(caption).font(.system(size: 12.5)).opacity(0.7).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            GlassToggle(theme: theme, isOn: form.binding(kp)).padding(.top, 2)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.text.color.opacity(theme.isDark ? 0.05 : 0.04)))
        .settle(n)
    }

    private var pages: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("Pages, and the keys", "A document you open stays open as a page, in a stack with the one you're writing on top. No tabs: hold ⌥ (or ⌃) and press Tab and the pages fan out across the window; let go to open one.")
                .settle(0)
            row("Keep pages open", "Off, a document opened takes the place of the last — one page at a time.") {
                GlassToggle(theme: theme, isOn: form.binding(\.keepPagesOpen))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.text.color.opacity(theme.isDark ? 0.05 : 0.04)))
            .settle(1)
            Text("WORTH KNOWING").font(.system(size: 10, weight: .semibold)).kerning(0.7).opacity(0.4)
                .padding(.top, 20).padding(.bottom, 8)
                .settle(2)
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 7) {
                    key("⌥⇥ / ⌃⇥", "The open pages, fanned out")
                    key("⌘1", "All Documents — the whole library as cards")
                    key("⌘2", "Timelapse — your daily notes, day by day")
                    key("⌘↩", "Review — the finished page, in six styles")
                    key("⌘⇧↩", "The page beside the editor, live")
                }
                VStack(alignment: .leading, spacing: 7) {
                    key("⌘K", "The command bar: anything, by name")
                    key("/", "At a line's start: headings, lists, tables, dates")
                    key("@today", "A date, as a capsule; @tomorrow too")
                    key("⌘/", "Every shortcut, on one sheet")
                    key("⌘,", "Settings — with a search box")
                }
            }
            .settle(3)
        }
    }

    private func key(_ k: String, _ what: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(k).font(.system(size: 11.5, weight: .semibold, design: .rounded)).foregroundStyle(theme.accent.color)
                .frame(width: 54, alignment: .trailing)
            Text(what).font(.system(size: 12.5)).opacity(0.8)
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("That's the tour.", "Everything here is in Settings (⌘,), and the manual at docs.glassine.ink has the rest — the Shelf, sync with GitHub, the Timelapse, the formatting bar, the slash menu, chips, and the things that move.")
                .settle(0)
            VStack(alignment: .leading, spacing: 12) {
                idea("Help → Tour of Glassine", "brings this back, any time.", 1)
                idea("⌘Z in Settings", "takes back any choice you made here, one at a time.", 2)
                idea("The Welcome page", "in the library walks through the editor itself — the bar over a selection, the slash menu, chips, dates.", 3)
            }
            Spacer()
            Text("Write something.")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.headingColor.asColor)
                .padding(.bottom, 10)
                .settle(4)
        }
    }

    private func row<Control: View>(_ title: String, _ caption: String?, @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                if let caption {
                    Text(caption).font(.system(size: 11)).opacity(0.55).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control()
        }
    }
}

/// A row settling into place a beat after the one before it.
private struct Settle: ViewModifier {
    let order: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 10)
            .onAppear {
                let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                withAnimation(reduce ? .none : .spring(response: 0.5, dampingFraction: 0.85).delay(0.12 + Double(order) * 0.07)) { shown = true }
            }
    }
}

private extension View {
    func settle(_ order: Int) -> some View { modifier(Settle(order: order)) }
}
