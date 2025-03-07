import Foundation
import AVFoundation
import SwiftUI

// Speech synthesizer delegate to handle completion
class SpeechSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
        super.init()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion()
    }
}

// Speech Manager to handle text-to-speech
class SpeechManager: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var delegate: SpeechSynthesizerDelegate?
    @Published private(set) var isSpeaking = false
    
    init() {
        setupAudioSession()
    }
    
    func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func speak(_ text: String, completion: @escaping (Bool) -> Void) {
        // Stop any ongoing speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Set playing state
        self.isSpeaking = true
        completion(true)
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        
        // Configure for Chinese
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.0  // Slow rate for better clarity
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0  // Maximum volume
        utterance.preUtteranceDelay = 0.1  // Add a small delay before speaking
        
        // Create and retain the delegate
        self.delegate = SpeechSynthesizerDelegate { [weak self] in
            DispatchQueue.main.async {
                self?.isSpeaking = false
                completion(false)
            }
        }
        
        // Set the delegate
        synthesizer.delegate = self.delegate
        
        // Speak the text
        print("Speaking text: \(text)")
        synthesizer.speak(utterance)
    }
} 