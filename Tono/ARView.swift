// ARView.swift
// Tono
//
// Created as part of the AR Gamified Chinese Learning App

import SwiftUI
import ARKit
import SceneKit
import RealityKit
import AVFoundation

struct ARExploreView: View {
    @StateObject private var arManager = ARManager()
    @State private var showARUnavailableAlert = false
    @State private var isPronouncing = false
    @State private var pronunciationCorrect = false
    @State private var showPronunciationFeedback = false
    
    // Audio player for pronunciation
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        ZStack {
            // AR View Container
            ARViewContainer(arManager: arManager)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay UI elements
            VStack {
                // Status indicator at the top
                HStack {
                    Image(systemName: arManager.isSessionRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(arManager.isSessionRunning ? .green : .red)
                    
                    Text(arManager.isSessionRunning ? "AR Session Running" : "AR Session Stopped")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Object detection indicator
                if arManager.objectRecognitionManager.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                }
                
                // Instructions for user
                Text("Tap on labeled objects to learn more")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
                    .padding(.bottom, 10)
                
                // Control buttons at the bottom
                HStack(spacing: 20) {
                    // Pause/Play button
                    Button(action: {
                        if arManager.isSessionRunning {
                            arManager.pauseSession()
                        } else {
                            arManager.startSession()
                        }
                    }) {
                        Image(systemName: arManager.isSessionRunning ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .cornerRadius(30)
                    }
                    
                    // Manual detection button
                    Button(action: {
                        arManager.detectObject()
                    }) {
                        Image(systemName: "camera.viewfinder")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.green)
                            .cornerRadius(30)
                    }
                    
                    // Reset button
                    Button(action: {
                        arManager.resetSession()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.orange)
                            .cornerRadius(30)
                    }
                }
                .padding(.bottom, 30)
            }
            
            // Object detection popup - now only shows when an object is tapped
            if arManager.showObjectPopup, let detection = arManager.selectedObject {
                ObjectPopupView(
                    detection: detection,
                    isShowing: $arManager.showObjectPopup,
                    isPronouncing: $isPronouncing,
                    pronunciationCorrect: $pronunciationCorrect,
                    showPronunciationFeedback: $showPronunciationFeedback
                )
            }
            
            // Pronunciation feedback
            if showPronunciationFeedback {
                VStack {
                    Image(systemName: pronunciationCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(pronunciationCorrect ? .green : .red)
                    
                    Text(pronunciationCorrect ? "Correct!" : "Try Again")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(15)
                .onAppear {
                    // Hide feedback after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showPronunciationFeedback = false
                    }
                }
            }
        }
        .onAppear {
            // Check if AR is supported
            if !ARWorldTrackingConfiguration.isSupported {
                showARUnavailableAlert = true
            }
            
            // Request camera and microphone permissions
            requestPermissions()
        }
        .alert(isPresented: $showARUnavailableAlert) {
            Alert(
                title: Text("AR Unavailable"),
                message: Text("ARKit is not available on this device."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Request necessary permissions
    private func requestPermissions() {
        // Camera permission is handled by ARKit
        
        // Request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            print("Microphone permission granted: \(granted)")
        }
    }
}

// Popup view for detected objects
struct ObjectPopupView: View {
    let detection: DetectedObject
    @Binding var isShowing: Bool
    @Binding var isPronouncing: Bool
    @Binding var pronunciationCorrect: Bool
    @Binding var showPronunciationFeedback: Bool
    
    // Audio player for pronunciation
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        VStack(spacing: 15) {
            // Object name in English
            Text(detection.englishName.capitalized)
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Chinese name
            Text(detection.chineseName)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.primary)
            
            // Pinyin
            Text(detection.pinyin)
                .font(.title3)
                .foregroundColor(.secondary)
            
            // Confidence
            Text("Confidence: \(detection.formattedConfidence)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Pronunciation button
            Button(action: {
                // Play pronunciation (simulated)
                playPronunciation()
            }) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                    Text("Listen")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            // Practice pronunciation button
            Button(action: {
                // Start recording (simulated)
                isPronouncing = true
                
                // Simulate pronunciation assessment
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isPronouncing = false
                    
                    // Random result for demonstration
                    pronunciationCorrect = Bool.random()
                    showPronunciationFeedback = true
                    
                    // Close popup if pronunciation is correct
                    if pronunciationCorrect {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isShowing = false
                        }
                    }
                }
            }) {
                HStack {
                    Image(systemName: isPronouncing ? "mic.fill" : "mic")
                    Text(isPronouncing ? "Listening..." : "Practice")
                }
                .padding()
                .background(isPronouncing ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isPronouncing)
            
            // Close button
            Button(action: {
                isShowing = false
            }) {
                Text("Close")
                    .foregroundColor(.blue)
            }
            .padding(.top, 5)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 10)
        .frame(width: 300)
        .padding()
    }
    
    // Play pronunciation (simulated)
    private func playPronunciation() {
        // In a real app, this would play an audio file or use text-to-speech
        print("Playing pronunciation for: \(detection.chineseName)")
        
        // Simulate audio playback
        // This would normally be:
        // if let url = Bundle.main.url(forResource: detection.englishName, withExtension: "mp3") {
        //     audioPlayer = try? AVAudioPlayer(contentsOf: url)
        //     audioPlayer?.play()
        // }
    }
}

struct ARExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ARExploreView()
    }
} 