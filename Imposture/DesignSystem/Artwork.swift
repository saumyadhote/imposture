import SwiftUI

/// Illustrations from the gogo Figma file ("gogo-app", Page 5).
enum Artwork {
    /// Pictures are off for this phase: screens show symbols and labelled placeholders instead.
    /// The assets stay in the catalog; set this to true to bring every illustration back.
    static let showsIllustrations = false

    /// Exercise art from the gogo file: multi-pose guides on their own dark card, shown edge
    /// to edge. Any other exercise art (the older drawings) is treated as missing for now.
    static let approvedExercises: Set<String> = ["shoulder-rolls", "chin-tuck", "neck-rotations", "side-neck-stretch", "back-neck-stretch"]

    static func isApproved(_ name: String) -> Bool {
        approvedExercises.contains(name)
    }

    /// Single-figure crops for catalogue rows, keyed by exercise ID.
    static let figures: [String: String] = [
        "shoulder-rolls": "figure-shoulder-rolls",
        "neck-rotations": "figure-neck-rotations",
        "side-neck-stretch": "figure-side-neck-stretch",
        "back-neck-stretch": "figure-back-neck-stretch",
        "chin-tuck": "figure-chin-tuck",
    ]

    static func figure(for exerciseID: String) -> String? {
        showsIllustrations ? figures[exerciseID] : nil
    }

    /// Scene art for stand-alone routines, keyed by routine ID. Routines without art use a symbol.
    static let routines: [String: String] = [
        "desk-reset": "relaxed-desk",
        "desk-stretches": "relaxed-desk",
        "gentle-mobility": "stretching-figures",
        "stand-up-break": "stretching-figures",
        "full-break": "stretching-figures",
        "posture-refresh": "posture-journey",
    ]

    static func scene(for routineID: String) -> String? {
        showsIllustrations ? routines[routineID] : nil
    }
}

extension BodyArea {
    /// Posture-strain figure for the area, or nil to use the SF Symbol.
    var artworkName: String? {
        guard Artwork.showsIllustrations else { return nil }
        return switch self {
        case .neck: "strain-tech-neck"
        case .shoulders: "strain-rounded-shoulders"
        case .upperBack: "strain-hump-neck"
        case .back: "strain-hunch-back"
        case .hips, .legs: nil
        }
    }
}
