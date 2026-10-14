import SwiftUI

/// The open pages fanned across the window while ⌥ is held (see Pages.swift):
/// a row of cards in the order the pages were last used, the highlighted one
/// lifted and the row slid so it sits at the middle. Each card is the page
/// itself in little — its title and its first lines in the theme's colours —
/// so a page is found by what is on it rather than by a name in a strip.
struct PageCarouselView: View {
    @EnvironmentObject var state: AppState
    let carousel: PageCarousel

    private var theme: Theme { state.theme }
    private static let cardWidth: CGFloat = 196
    private static let cardHeight: CGFloat = 150
    private static let gap: CGFloat = 18

    private var documents: [DocumentRef] {
        carousel.order.compactMap { state.library.document(withID: $0) }
    }

    var body: some View {
        GeometryReader { geo in
            let docs = documents
            let step = Self.cardWidth + Self.gap
            // The highlighted card sits at the middle; the row slides under it.
            let offset = (geo.size.width - Self.cardWidth) / 2 - CGFloat(carousel.index) * step
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { state.cancelCarousel() }
                HStack(spacing: Self.gap) {
                    ForEach(Array(docs.enumerated()), id: \.element.id) { i, doc in
                        PageCard(doc: doc, highlighted: i == carousel.index, current: state.document?.relativePath == doc.id)
                            .frame(width: Self.cardWidth, height: Self.cardHeight)
                            .scaleEffect(i == carousel.index ? 1 : 0.9)
                            .opacity(i == carousel.index ? 1 : 0.72)
                            .zIndex(i == carousel.index ? 1 : 0)
                            .onTapGesture { state.pickFromCarousel(doc.id) }
                    }
                }
                .offset(x: offset, y: (geo.size.height - Self.cardHeight) / 2 - 10)
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: carousel.index)
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: carousel.order)

                // The highlighted page's name, and the keys, under the row.
                VStack(spacing: 6) {
                    if carousel.index < docs.count {
                        Text(docs[carousel.index].title)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.headingColor.asColor.opacity(0.9))
                            .lineLimit(1)
                            .contentTransition(.opacity)
                    }
                    Text("Tab to step · ⌫ closes · let go of ⌥ to open")
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .foregroundStyle(theme.text.color.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .offset(y: (geo.size.height + Self.cardHeight) / 2 + 10)
                .animation(.easeOut(duration: 0.12), value: carousel.index)
            }
        }
        .ignoresSafeArea()
    }
}

/// A page in little: its title and its first lines, as the mosaic's cards
/// draw them, on a plate of the theme's glass.
struct PageCard: View {
    @EnvironmentObject var state: AppState
    let doc: DocumentRef
    var highlighted: Bool
    var current: Bool

    private var theme: Theme { state.theme }
    private var lines: [PreviewLine] { Array(MarkdownPreview.lines(for: doc, limit: 10).prefix(9)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(doc.title)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(theme.headingColor.asColor)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(lines) { line in
                    PreviewLineView(line: line, theme: theme)
                }
            }
            .foregroundStyle(theme.text.color.opacity(0.72))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.tint.color.opacity(theme.isDark ? 0.82 : 0.9))
        )
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.text.color.opacity(highlighted ? 0.1 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(highlighted ? theme.accent.color.opacity(0.95) : theme.text.color.opacity(current ? 0.28 : 0.1),
                              lineWidth: highlighted ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(highlighted ? (theme.isDark ? 0.4 : 0.18) : 0.12), radius: highlighted ? 18 : 8, y: highlighted ? 8 : 3)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// The open pages as a row of pips in the footer: one a page, the one on
/// screen lit, in the order they were last used. A click goes to that page;
/// the pointer over one names it.
struct PagePips: View {
    @EnvironmentObject var state: AppState
    @State private var hovered: String?

    private var theme: Theme { state.theme }

    var body: some View {
        let pages = state.openPages.filter { state.library.document(withID: $0) != nil }
        if state.keepsPagesOpen, pages.count > 1 {
            HStack(spacing: 5) {
                ForEach(pages.prefix(9), id: \.self) { id in
                    let isCurrent = state.document?.relativePath == id
                    Capsule()
                        .fill(isCurrent ? theme.accent.color.opacity(0.9) : theme.text.color.opacity(hovered == id ? 0.6 : 0.28))
                        .frame(width: isCurrent ? 12 : 5, height: 5)
                        .contentShape(Rectangle().inset(by: -4))
                        .onHover { hovered = $0 ? id : (hovered == id ? nil : hovered) }
                        .onTapGesture { state.switchToPage(id) }
                        .help((state.library.document(withID: id)?.title ?? id) + " — ⌥Tab moves between pages")
                }
                if pages.count > 9 {
                    Text("+\(pages.count - 9)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .opacity(0.5)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: state.document?.relativePath)
            .animation(.easeOut(duration: 0.15), value: pages)
            .padding(.leading, 6)
        }
    }
}
