import SwiftUI

extension Notification.Name {
    /// Asks the editor showing a document to put the caret at a position and
    /// bring its line to the top: userInfo "document" (the document's id) and
    /// "location" (in UTF-16 units).
    static let glassineRevealLocation = Notification.Name("glassine.revealLocation")
}

/// The page's headings, beside the editor (⌥⌘O): indented by level, the one
/// the caret is under marked, a click to go to one. Read from the text as it
/// changes, so it is never out of date.
struct OutlineView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject var document: DocumentModel
    @State private var hovered: Int?

    private var theme: Theme { state.theme }

    var body: some View {
        let headings = Outline.headings(in: document.text)
        let current = Outline.current(in: headings, caret: state.outlineCaret)?.id
        let top = headings.map(\.level).min() ?? 1
        VStack(alignment: .leading, spacing: 0) {
            Text("Outline")
                .font(.system(size: 11, weight: .medium))
                .textCase(.uppercase)
                .tracking(0.6)
                .opacity(0.45)
                .padding(.horizontal, 16)
                .padding(.top, 52)
                .padding(.bottom, 10)
            if headings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No headings yet")
                        .font(.system(size: 12.5))
                        .opacity(0.6)
                    Text("Lines that start with # show up here.")
                        .font(.system(size: 11))
                        .opacity(0.4)
                }
                .padding(.horizontal, 16)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(headings) { heading in
                                row(heading, indent: heading.level - top, isCurrent: heading.id == current)
                                    .id(heading.id)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 24)
                    }
                    .onChange(of: current) { _, id in
                        guard let id else { return }
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(theme.text.color)
    }

    private func row(_ heading: Outline.Heading, indent: Int, isCurrent: Bool) -> some View {
        Text(heading.title)
            .font(.system(size: 12.5, weight: heading.level == 1 ? .semibold : .regular))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .opacity(isCurrent ? 1 : 0.62)
            .padding(.leading, 8 + CGFloat(min(indent, 5)) * 12)
            .padding(.trailing, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.text.color.opacity(isCurrent ? (theme.isDark ? 0.10 : 0.07)
                                                   : hovered == heading.id ? (theme.isDark ? 0.05 : 0.035) : 0))
            )
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { hovered = heading.id } else if hovered == heading.id { hovered = nil }
            }
            .onTapGesture { reveal(heading) }
            .help(heading.title)
    }

    private func reveal(_ heading: Outline.Heading) {
        state.outlineCaret = heading.location
        NotificationCenter.default.post(name: .glassineRevealLocation, object: nil,
                                        userInfo: ["document": document.id, "location": heading.location])
    }
}
