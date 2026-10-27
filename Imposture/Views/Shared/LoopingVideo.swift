import AVFoundation
import SwiftUI
import UIKit

/// A bundled video that plays on a silent loop with no playback controls.
/// Holds on the first frame when Reduce Motion is on.
struct LoopingVideo: View {
    let resource: String
    var fileExtension = "mp4"
    var contentMode: ContentMode = .fit
    /// Fades the frame's edges to transparent so the video melts into what's behind it.
    var fadesEdges = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var player = AVQueuePlayer()
    @State private var looper: AVPlayerLooper?

    var body: some View {
        PlayerLayerView(player: player, videoGravity: contentMode == .fill ? .resizeAspectFill : .resizeAspect, fadesEdges: fadesEdges)
            .accessibilityHidden(true)
            .onAppear {
                if looper == nil, let url = Bundle.main.url(forResource: resource, withExtension: fileExtension) {
                    player.isMuted = true
                    player.preventsDisplaySleepDuringVideoPlayback = false
                    looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
                }
                if !reduceMotion { player.play() }
            }
            .onDisappear { player.pause() }
            .onChange(of: reduceMotion) { _, reduce in
                reduce ? player.pause() : player.play()
            }
    }
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity
    let fadesEdges: Bool

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer?.player = player
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        view.playerLayer?.videoGravity = videoGravity
        view.fadesEdges = fadesEdges
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }

        var fadesEdges = false {
            didSet { setNeedsLayout() }
        }

        /// A SwiftUI mask doesn't reach the player layer, so the fade is a layer mask.
        private lazy var edgeFade: CAGradientLayer = {
            let gradient = CAGradientLayer()
            gradient.type = .radial
            gradient.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
            gradient.locations = [0, 0.55, 1]
            gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 1)
            return gradient
        }()

        override func layoutSubviews() {
            super.layoutSubviews()
            guard fadesEdges else {
                layer.mask = nil
                return
            }
            // A circle that reaches the nearer pair of edges, centred in the frame.
            let side = min(bounds.width, bounds.height)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            edgeFade.frame = CGRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
            CATransaction.commit()
            layer.mask = edgeFade
        }
    }
}

#Preview {
    LoopingVideo(resource: "posture_loop")
        .aspectRatio(contentMode: .fit)
        .padding()
}
