// Ported from the vyam onboarding (Team-5).
//
//  Siri-powered voice guidance director for multi-angle posture scanning.
//  Provides clinical spoken instructions, distance coaching, and audio countdowns
//  especially vital for the dorsal (back) scan where the user cannot see the screen.
//

import Foundation
import Combine
import AVFoundation

@MainActor
public final class PostureScanVoiceDirector: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = PostureScanVoiceDirector()
    
    @Published public var isMuted: Bool = false
    @Published public var isSpeaking: Bool = false
    @Published public var currentSpokenPrompt: String = ""
    
    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpokenMessage: String = ""
    private var lastSpokenTimestamp: Date = .distantPast
    private var lastCountdownSecond: Int = -1
    private var selectedVoice: AVSpeechSynthesisVoice?
    
    override public init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        selectedVoice = resolveBestSiriVoice()
    }
    
    // MARK: - Audio Session Configuration
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[VoiceDirector] Audio session setup error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Voice Selection (Prefers Siri / Enhanced English)
    private func resolveBestSiriVoice() -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Priority 1: Official Siri voice identifiers
        if let siriVoice = allVoices.first(where: {
            $0.identifier.lowercased().contains("siri") && $0.language.hasPrefix("en")
        }) {
            return siriVoice
        }
        
        // Priority 2: Enhanced quality US English voices (e.g., Samantha Enhanced, Alex, Ava)
        if let enhancedVoice = allVoices.first(where: {
            $0.language == "en-US" && ($0.quality == .enhanced || $0.quality == .premium)
        }) {
            return enhancedVoice
        }
        
        // Priority 3: Standard clean US English system voice
        return AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice(language: Locale.current.identifier)
    }
    
    // MARK: - Public Speaking API
    public func speak(_ text: String, force: Bool = false, rate: Float = 0.50, preDelay: TimeInterval = 0) {
        guard !isMuted else { return }
        
        let now = Date()
        if !force && text == lastSpokenMessage && now.timeIntervalSince(lastSpokenTimestamp) < 3.2 {
            return
        }
        
        lastSpokenMessage = text
        lastSpokenTimestamp = now
        currentSpokenPrompt = text
        
        if force && synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice ?? resolveBestSiriVoice()
        utterance.rate = rate
        utterance.pitchMultiplier = 1.02
        utterance.volume = 1.0
        utterance.preUtteranceDelay = preDelay
        
        synthesizer.speak(utterance)
    }
    
    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        currentSpokenPrompt = ""
    }
    
    public func toggleMute() -> Bool {
        isMuted.toggle()
        if isMuted {
            stop()
        }
        return isMuted
    }
    
    // MARK: - Context-Aware Scanning Announcements
    public func announceAngleIntro(for angle: ScanAngle) {
        lastCountdownSecond = -1
        switch angle {
        case .front:
            speak("Face the camera and stand with your arms relaxed by your sides.", force: true)
        case .right:
            speak("Turn ninety degrees to your right side.", force: true)
        case .left:
            speak("Turn ninety degrees to your left side.", force: true)
        case .back:
            // Dedicated spoken guidance for the dorsal scan
            speak("Turn your back completely to the camera. Don't worry, I will guide you by voice.", force: true)
        }
    }
    
    public func announceGuidanceWarning(_ message: String) {
        guard !synthesizer.isSpeaking else { return }
        speak(message, force: false)
    }
    
    public func announceHolding(for angle: ScanAngle, progress: Double) {
        if angle == .back {
            // Spoken countdown for back scan since user is looking away
            let secondsRemaining = max(1, Int(ceil((1.0 - progress) * 2.0)))
            if secondsRemaining != lastCountdownSecond && !synthesizer.isSpeaking {
                lastCountdownSecond = secondsRemaining
                if secondsRemaining == 1 {
                    speak("Hold still. Capturing now.", force: true, rate: 0.52)
                } else {
                    speak("Hold still. \(secondsRemaining)...", force: true, rate: 0.52)
                }
            }
        } else {
            speak("Hold still...", force: false)
        }
    }
    
    public func announceBurstCaptured(for angle: ScanAngle, nextAngle: ScanAngle?) {
        lastCountdownSecond = -1
        if let next = nextAngle {
            if angle == .back {
                speak("Back scan verified! You can turn back around now.", force: true)
            } else {
                speak("\(angle.rawValue) captured! Next, \(next.subtitle.lowercased()).", force: true)
            }
        } else {
            speak("All four scans completed! Generating your posture report.", force: true)
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }
    
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
    
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
