import SwiftUI

/// A ring of short segments that fills clockwise from the top in the green ring gradient.
/// Nil draws the empty track only, and only a real value is ever animated in.
struct ScoreRing<Center: View>: View {
    let progress: Double?
    var size: CGFloat = 116
    @ViewBuilder var center: Center
    @ScaledMetric(relativeTo: .title) private var scale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    private let segments = 30
    private let gap = 0.006

    var body: some View {
        let side = size * scale
        let filled = Int(((progress ?? 0) * Double(segments) * shown).rounded())
        ZStack {
            ForEach(0..<segments, id: \.self) { index in
                Circle()
                    .trim(from: Double(index) / Double(segments) + gap, to: Double(index + 1) / Double(segments) - gap)
                    .stroke(Color.impostureDashboardElevated, style: StrokeStyle(lineWidth: side * 0.075, lineCap: .butt))
                    .overlay {
                        // The gradient is laid over the whole ring, so it runs continuously across segments.
                        if index < filled {
                            Circle()
                                .trim(from: Double(index) / Double(segments) + gap, to: Double(index + 1) / Double(segments) - gap)
                                .stroke(BrandGradient.ring, style: StrokeStyle(lineWidth: side * 0.075, lineCap: .butt))
                        }
                    }
                    .rotationEffect(.degrees(-90))
            }
            center
        }
        .padding(side * 0.04)
        .frame(width: side, height: side)
        .onAppear { reveal() }
        .onChange(of: progress) { reveal() }
    }

    private func reveal() {
        guard progress != nil else { shown = 0; return }
        shown = reduceMotion ? 1 : 0
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6)) { shown = 1 }
    }
}
