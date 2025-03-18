//
//  SpeechManager.swift
//  YOLO
//
//  Created as part of the Tono integration
//

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
        print("Speech completed successfully")
        completion()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("Speech was cancelled")
        completion()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("Speech started")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("Speech paused")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        print("Speech continued")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // This can be used to track speech progress if needed
    }
}

// Speech Manager to handle text-to-speech
class SpeechManager: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var delegate: SpeechSynthesizerDelegate?
    @Published private(set) var isSpeaking = false
    @Published private(set) var errorMessage: String? = nil
    
    init() {
        setupAudioSession()
    }
    
    func setupAudioSession() {
        #if os(iOS) || os(tvOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use playback category for better compatibility
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Print current audio route for debugging
            printCurrentAudioRoute()
            
            print("Audio session setup successful with category: \(audioSession.category.rawValue), mode: \(audioSession.mode.rawValue)")
        } catch {
            print("Failed to set up audio session: \(error)")
            errorMessage = "Audio setup failed: \(error.localizedDescription)"
        }
        #endif
    }
    
    private func printCurrentAudioRoute() {
        #if os(iOS) || os(tvOS)
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        print("Current audio route:")
        for output in currentRoute.outputs {
            print(" - Output: \(output.portName) (type: \(output.portType.rawValue))")
        }
        for input in currentRoute.inputs {
            print(" - Input: \(input.portName) (type: \(input.portType.rawValue))")
        }
        #endif
    }
    
    func speak(_ text: String, completion: @escaping (Bool) -> Void) {
        guard !text.isEmpty else {
            print("Error: Empty text provided to speak()")
            completion(false)
            return
        }
        
        // Ensure audio session is active
        activateAudioSession()
        
        // Stop any ongoing speech
        if synthesizer.isSpeaking {
            print("Stopping current speech to start new one")
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Set playing state
        self.isSpeaking = true
        completion(true)
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        
        // Configure for Chinese
        let voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.voice = voice
        
        // Log available voices for Chinese
        logAvailableVoices()
        
        print("Using voice: \(voice?.language ?? "unknown") \(voice?.name ?? "unnamed")")
        
        utterance.rate = 0.0  // Keep this at 0.0!
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
        print("Speaking text: \"\(text)\"")
        synthesizer.speak(utterance)
    }
    
    private func activateAudioSession() {
        #if os(iOS) || os(tvOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            if !audioSession.isOtherAudioPlaying {
                // Only set category if no other audio is playing
                try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            }
            
            // Always try to activate the session
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Print current audio route after activation
            printCurrentAudioRoute()
        } catch {
            print("Failed to activate audio session: \(error)")
            errorMessage = "Audio activation failed: \(error.localizedDescription)"
        }
        #endif
    }
    
    private func logAvailableVoices() {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let chineseVoices = voices.filter { $0.language.hasPrefix("zh") }
        
        print("Available Chinese voices (\(chineseVoices.count)):")
        for voice in chineseVoices {
            print(" - \(voice.name) (language: \(voice.language))")
        }
    }
} 