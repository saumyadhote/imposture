import SwiftUI

/// A paged, depth-lit carousel. The centred card faces forward; its neighbours turn away
/// around the vertical axis and fall back, and every card's turn, scale and depth track the
/// scroll offset continuously, so a drag moves the whole set as one.
struct DepthCarousel<Item: Identifiable, Card: View>: View where Item.ID: Hashable & Sendable {
    let items: [Item]
    /// Prefix for each card's accessibility identifier, followed by the item's ID.
    var identifier = "carousel"
    @ViewBuilder var card: (Item) -> Card

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: ScrollPosition
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 236

    /// `initial` is centred when the carousel first appears.
    init(items: [Item], initial: Item.ID? = nil, identifier: String = "carousel", @ViewBuilder card: @escaping (Item) -> Card) {
        self.items = items
        self.identifier = identifier
        self.card = card
        var position = ScrollPosition(idType: Item.ID.self)
        if let initial { position.scrollTo(id: initial, anchor: .center) }
        _position = State(initialValue: position)
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = CarouselLayout(containerWidth: geometry.size.width)
            // Plain values, so the per-frame effect closure captures nothing actor-bound.
            let (step, cardWidth, reduceMotion) = (layout.step, layout.cardWidth, reduceMotion)
            ScrollView(.horizontal) {
                LazyHStack(spacing: layout.spacing) {
                    ForEach(items) { item in
                        card(item)
                            .frame(width: layout.cardWidth, height: cardHeight)
                            .visualEffect { content, proxy in
                                content.carouselDepth(
                                    CarouselLayout.distance(of: proxy, step: step),
                                    cardWidth: cardWidth,
                                    reduceMotion: reduceMotion
                                )
                            }
                            .id(item.id)
                            // A container, so the identifier names the card without overwriting its buttons'.
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("\(identifier).\(item.id)")
                    }
                }
                .scrollTargetLayout()
                .offset(x: -debugPhase * step)
            }
            .contentMargins(.horizontal, layout.sideInset, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition($position, anchor: .center)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .sensoryFeedback(.selection, trigger: position.viewID(type: Item.ID.self))
        }
        // Room for the soft shadow, which the scroll view would otherwise clip.
        .frame(height: cardHeight + Spacing.xxl)
    }

    /// Debug builds accept `-carouselPhase <cards>` (for example 0.5) to freeze the set
    /// part-way through a swipe, so a mid-transition frame can be inspected.
    private var debugPhase: CGFloat {
        #if DEBUG
        CGFloat(UserDefaults.standard.double(forKey: "carouselPhase"))
        #else
        0
        #endif
    }
}

// MARK: - Layout

/// Card sizing, chosen so about a sixth of each neighbour stays in view.
private struct CarouselLayout {
    let containerWidth: CGFloat

    var cardWidth: CGFloat { (containerWidth * 0.7).rounded() }
    var spacing: CGFloat { Spacing.sm }
    var sideInset: CGFloat { (containerWidth - cardWidth) / 2 }
    var step: CGFloat { cardWidth + spacing }

    /// Signed distance of a card from the centre of the viewport, in cards.
    /// 0 is centred, -1 is the left neighbour, 1 the right.
    nonisolated static func distance(of proxy: GeometryProxy, step: CGFloat) -> CGFloat {
        guard let viewport = proxy.bounds(of: .scrollView(axis: .horizontal)), step > 0 else { return 0 }
        let frame = proxy.frame(in: .scrollView(axis: .horizontal))
        return (frame.midX - viewport.midX) / step
    }
}

private extension VisualEffect {
    /// Maps a card's distance from centre to its turn, scale and depth.
    /// Everything is a continuous function of `distance`, so there are no jumps between pages.
    nonisolated func carouselDepth(_ distance: CGFloat, cardWidth: CGFloat, reduceMotion: Bool) -> some VisualEffect {
        // Beyond the first neighbour the pose holds; those cards are off screen.
        let d = min(max(distance, -1.5), 1.5)
        let near = min(abs(d), 1)
        // Ease in so the centre card turns gently as it starts to leave.
        let eased = near * near * (3 - 2 * near)

        let side: CGFloat = d < 0 ? -eased : eased

        let angle = reduceMotion ? 0 : -Double(side) * 38
        let scale = 1 - (reduceMotion ? 0.04 : 0.08) * eased
        // Turning a card narrows it, which opens the gap; pull neighbours back in.
        let pull = reduceMotion ? 0 : -side * cardWidth * 0.18

        return self
            .scaleEffect(scale)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
            .offset(x: pull)
    }
}
