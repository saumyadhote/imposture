// Ported from the vyam onboarding (Team-5): the body-scan onboarding's models and validation.

import Foundation
import CoreGraphics

// MARK: - Onboarding Slide Model
nonisolated public struct OnboardingSlide: Identifiable, Equatable, Sendable {
    public let id: Int
    public let tag: String
    public let title: String
    public let subtitle: String
    public let illustrationAsset: String
    public let visualSymbol: String
    public let tintHex: String
    
    public var imageName: String { illustrationAsset }
    public var description: String { subtitle }
    
    public init(id: Int, tag: String = "", title: String, subtitle: String, illustrationAsset: String, visualSymbol: String = "", tintHex: String = "D6F34C") {
        self.id = id
        self.tag = tag
        self.title = title
        self.subtitle = subtitle
        self.illustrationAsset = illustrationAsset
        self.visualSymbol = visualSymbol
        self.tintHex = tintHex
    }
}

nonisolated public enum OnboardingContent {
    public static let slides: [OnboardingSlide] = [
        OnboardingSlide(
            id: 0,
            tag: "STRETCH",
            title: "Stretch to Strength",
            subtitle: "Get a personalised posture plan with expert reviewed exercises that progress from mobility to strength.",
            illustrationAsset: "onboarding_1",
            visualSymbol: "figure.walk",
            tintHex: "D6F34C"
        ),
        OnboardingSlide(
            id: 1,
            tag: "POSTURE",
            title: "Check your posture",
            subtitle: "Set up your phone while you are working and get a live feed of your posture throughout and improve it.",
            illustrationAsset: "onboarding_2",
            visualSymbol: "iphone",
            tintHex: "D6F34C"
        ),
        OnboardingSlide(
            id: 2,
            tag: "PROGRAMME",
            title: "Ten days, one step at a time",
            subtitle: "Short guided sessions that build day by day.\nStart your Day 1 today.",
            illustrationAsset: "onboarding_3",
            visualSymbol: "star.fill",
            tintHex: "D6F34C"
        )
    ]
}

public typealias OnboardingData = OnboardingContent

// MARK: - Focus Areas Selection (Figma Node: 2131:2879 - 4 Primary Cards)
nonisolated public enum FocusArea: String, CaseIterable, Identifiable, Equatable, Hashable, Sendable {
    case humpNeck = "Hump neck"
    case hunchBack = "Hunch back"
    case techNeck = "Tech neck"
    case roundedShoulders = "Rounded shoulders"
    
    public var id: String { rawValue }
    public var title: String { rawValue }
    
    public var imageName: String {
        switch self {
        case .humpNeck: return "focus_hump_neck"
        case .hunchBack: return "focus_hunch_back"
        case .techNeck: return "focus_tech_neck"
        case .roundedShoulders: return "focus_rounded_shoulders"
        }
    }
    
    public var iconName: String {
        switch self {
        case .humpNeck: return "iphone"
        case .techNeck: return "iphone"
        case .roundedShoulders: return "figure.arms.open"
        case .hunchBack: return "figure.walk"
        }
    }
    
    public var description: String {
        switch self {
        case .humpNeck: return "Fatty deposit and cervical curvature at base of the neck"
        case .techNeck: return "Forward head posture from looking down at phones and laptops"
        case .roundedShoulders: return "Shoulders rolling forward while typing or writing"
        case .hunchBack: return "Curvature through the upper and middle thoracic spine"
        }
    }
}

// MARK: - Posture Scan Step Angles
nonisolated public enum ScanAngle: String, CaseIterable, Identifiable, Equatable, Hashable, Sendable {
    case front = "Front"
    case right = "Right"
    case left = "Left"
    case back = "Back"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .front: return "Front View"
        case .right: return "Right Side"
        case .left: return "Left Side"
        case .back: return "Back View"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .front: return "Stand naturally facing the camera"
        case .right: return "Turn 90° to show your right side"
        case .left: return "Turn 90° to show your left side"
        case .back: return "Turn around facing away from camera"
        }
    }
    
    public var nextAngle: ScanAngle? {
        switch self {
        case .front: return .right
        case .right: return .left
        case .left: return .back
        case .back: return nil
        }
    }
    
    public var previousAngle: ScanAngle? {
        switch self {
        case .front: return nil
        case .right: return .front
        case .left: return .right
        case .back: return .left
        }
    }
}

// MARK: - Posture Diagnostic Findings
nonisolated public enum FindingSeverity: String, Equatable, Hashable, Sendable {
    case mild
    case moderate
    case significant
}

nonisolated public struct PostureFinding: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let severity: FindingSeverity
    
    public init(id: String = UUID().uuidString, title: String, detail: String, severity: FindingSeverity = .moderate) {
        self.id = id
        self.title = title
        self.detail = detail
        self.severity = severity
    }
}

// MARK: - Baseline Assessment Result

/// What the onboarding scan found. Empty when the scan was skipped or measured nothing.
nonisolated public struct BaselineAssessment: Equatable, Sendable {
    public var selectedFocusAreas: Set<FocusArea>
    public var findings: [PostureFinding]
    public var clinicalMetrics: [ClinicalMetric]
    public var cvaAngle: Double?
    public var shoulderTiltAngle: Double?
    /// Frames actually captured across all views.
    public var capturedFrames: Int
    public var isScanCompleted: Bool

    /// True when at least one metric was measured.
    public var hasMeasurements: Bool { !clinicalMetrics.isEmpty }

    /// Measurements that fell within their guide range.
    public var withinGuideCount: Int { clinicalMetrics.count { $0.status == .optimal } }

    /// Share of measurements within their guide range, or nil when nothing was measured.
    /// A plain ratio of what was measured, not a posture score.
    public var withinGuideShare: Double? {
        hasMeasurements ? Double(withinGuideCount) / Double(clinicalMetrics.count) : nil
    }

    public init(
        selectedFocusAreas: Set<FocusArea> = [],
        findings: [PostureFinding] = [],
        clinicalMetrics: [ClinicalMetric] = [],
        cvaAngle: Double? = nil,
        shoulderTiltAngle: Double? = nil,
        capturedFrames: Int = 0,
        isScanCompleted: Bool = false
    ) {
        self.selectedFocusAreas = selectedFocusAreas
        self.findings = findings
        self.clinicalMetrics = clinicalMetrics
        self.cvaAngle = cvaAngle
        self.shoulderTiltAngle = shoulderTiltAngle
        self.capturedFrames = capturedFrames
        self.isScanCompleted = isScanCompleted
    }

    /// The scan was skipped: keep the focus choices and claim nothing else.
    public static func skipped(focus: Set<FocusArea>) -> BaselineAssessment {
        BaselineAssessment(selectedFocusAreas: focus)
    }

    /// Builds the assessment from captured scan data.
    public static func generate(from focusAreas: Set<FocusArea>, scanData: MultiAngleScanData) -> BaselineAssessment {
        let analysis = ClinicalPostureAnalyzer.analyzeScan(scanData: scanData, userFocus: focusAreas)
        return BaselineAssessment(
            selectedFocusAreas: focusAreas,
            findings: analysis.findings,
            clinicalMetrics: analysis.metrics,
            cvaAngle: analysis.cvaAngle,
            shoulderTiltAngle: analysis.shoulderTiltAngle,
            capturedFrames: analysis.totalCalibratedFrames,
            isScanCompleted: true
        )
    }
}

extension FocusArea {
    /// The app's body area for this concern, so the choice carries into the plan.
    var bodyArea: BodyArea {
        switch self {
        case .techNeck: .neck
        case .roundedShoulders: .shoulders
        case .hunchBack: .back
        case .humpNeck: .upperBack
        }
    }
}

// MARK: - Onboarding Step State Machine
nonisolated public enum OnboardingStep: Equatable, Hashable, Sendable {
    case splash
    case carousel(page: Int)
    case nameInput
    case focusSelection
    case scanIntro
    case scanCapture(angle: ScanAngle)
    case baselineResults
    case completed
}

// MARK: - User Name Validation
nonisolated public enum NameValidationError: String, Equatable, Sendable, Error {
    case empty = "Please enter your name."
    case tooShort = "Name must be at least 2 characters."
    case tooLong = "Name cannot exceed 50 characters."
    case invalidCharacters = "Name can only contain letters, spaces, hyphens, and apostrophes."
}

nonisolated public struct UserNameValidator: Sendable {
    public static let minLength = 2
    public static let maxLength = 50
    
    public static func sanitize(_ input: String) -> String {
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public static func isValid(_ input: String) -> Bool {
        switch validate(input) {
        case .success: return true
        case .failure: return false
        }
    }
    
    public static func validate(_ input: String) -> Result<String, NameValidationError> {
        let trimmed = sanitize(input)
        
        if trimmed.isEmpty {
            return .failure(.empty)
        }
        
        if trimmed.count < minLength {
            return .failure(.tooShort)
        }
        
        if trimmed.count > maxLength {
            return .failure(.tooLong)
        }
        
        let allowedPattern = "^[\\p{L}\\s'-]+$"
        let isValid = trimmed.range(of: allowedPattern, options: .regularExpression) != nil
        if !isValid {
            return .failure(.invalidCharacters)
        }
        
        return .success(trimmed)
    }
}
