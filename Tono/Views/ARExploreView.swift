// ARExploreView.swift
// Tono
//
// Created as part of the AR Gamified Chinese Learning App

import SwiftUI
import AVFoundation
import CoreData

struct ARExploreView: View {
    @State private var detectedObject: (english: String, chinese: String, pinyin: String)?
    @State private var showPopup = false
    @State private var hasPronounced = false
    @State private var isRecording = false
    @State private var feedbackMessage = ""
    @State private var feedbackColor = Color.gray
    @State private var showFeedback = false
    
    // Audio session properties
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    
    // Speech manager for text-to-speech
    @StateObject private var speechManager = SpeechManager()
    
    // Pronunciation API
    @StateObject private var pronunciationAPI = PronunciationAPI()
    
    // This property will be set by the parent view (ContentView)
    var isActive: Bool = true
    
    // Environment for Core Data
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        ZStack {
            // AR View
            ARViewWrapper(
                onObjectDetected: { english, chinese, pinyin in
                    detectedObject = (english, chinese, pinyin)
                    showPopup = true
                    hasPronounced = false
                    showFeedback = false
                    feedbackMessage = ""
                },
                isActive: isActive
            )
            .edgesIgnoringSafeArea(.all)
            
            // Popup for detected object
            if showPopup, let object = detectedObject {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Text(object.chinese)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.red)
                        
                        HStack(spacing: 8) {
                            Text(object.pinyin)
                                .font(.system(size: 24))
                                .foregroundColor(.orange)
                            
                            Button(action: {
                                speechManager.speak(object.chinese) { _ in }
                            }) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.blue)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .disabled(speechManager.isSpeaking)
                            .opacity(speechManager.isSpeaking ? 0.6 : 1.0)
                        }
                        
                        Text(object.english)
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                        
                        // Pronunciation recording button
                        Button(action: {
                            if isRecording {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(isRecording ? Color.red : Color.blue)
                                    .frame(width: 60, height: 60)
                                
                                if isRecording {
                                    Circle()
                                        .stroke(Color.red, lineWidth: 4)
                                        .frame(width: 70, height: 70)
                                }
                                
                                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        }
                        .disabled(pronunciationAPI.isProcessing)
                        .padding(.vertical, 5)
                        
                        // Loading indicator during API processing
                        if pronunciationAPI.isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                                .padding(.vertical, 5)
                        }
                        
                        // Feedback message
                        if showFeedback {
                            Text(feedbackMessage)
                                .font(.headline)
                                .foregroundColor(feedbackColor)
                                .padding()
                                .background(feedbackColor.opacity(0.1))
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                        
                        HStack(spacing: 20) {
                            // Close button
                            Button(action: {
                                showPopup = false
                                hasPronounced = false
                            }) {
                                Text("Close")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(width: 100)
                                    .background(Color.gray)
                                    .cornerRadius(10)
                            }
                            
                            // Save button - only enabled after pronunciation
                            Button(action: {
                                saveObject(object)
                                showPopup = false
                                hasPronounced = false
                            }) {
                                Text("Save")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(width: 100)
                                    .background(hasPronounced ? Color.green : Color.gray.opacity(0.5))
                                    .cornerRadius(10)
                            }
                            .disabled(!hasPronounced)
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(15)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            
            // UI Controls
            VStack {
                // Top controls
                HStack {
                    // Reset button
                    Button(action: {
                        // Post notification directly to clear labels
                        NotificationCenter.default.post(name: NSNotification.Name("ClearARLabels"), object: nil)
                    }) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.blue.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(radius: 3)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1.5)
                                    .opacity(0.7)
                            )
                    }
                    .padding(.leading, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Instructions
                    Text("Tap on objects to identify them")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding(.top, 10)
                        .padding(.trailing, 20)
                }
                
                Spacer()
            }
        }
        .alert(item: Binding<AlertItem?>(
            get: { 
                if let error = pronunciationAPI.error {
                    return AlertItem(message: error)
                }
                return nil
            },
            set: { _ in pronunciationAPI.error = nil }
        )) { alertItem in
            Alert(
                title: Text("Error"),
                message: Text(alertItem.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Set up audio recording session
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            // Request microphone permission
            audioSession.requestRecordPermission { allowed in
                if !allowed {
                    self.feedbackMessage = "Microphone access is required for pronunciation practice"
                    self.feedbackColor = .red
                    self.showFeedback = true
                }
            }
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    // Start recording audio
    private func startRecording() {
        // Set up audio session if needed
        setupAudioSession()
        
        // Create a temporary URL for the recording
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("ar_pronunciation_recording.m4a")
        
        // Recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.record()
            isRecording = true
            
            // Automatically stop recording after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if self.isRecording {
                    self.stopRecording()
                }
            }
        } catch {
            print("Failed to start recording: \(error)")
            feedbackMessage = "Failed to start recording"
            feedbackColor = .red
            showFeedback = true
        }
    }
    
    // Stop recording and process the audio
    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        // Process the recording
        processPronunciation()
    }
    
    // Process the pronunciation recording
    private func processPronunciation() {
        guard let recordingURL = recordingURL, let chineseText = detectedObject?.chinese else {
            feedbackMessage = "Missing recording or text data"
            feedbackColor = .red
            showFeedback = true
            return
        }
        
        // Send the recording to the Fluent API for assessment
        pronunciationAPI.assessPronunciation(audioURL: recordingURL, text: chineseText) { result in
            switch result {
            case .success(let pronunciationResult):
                // Process the result
                let score = pronunciationResult.score
                
                if score > 80 {
                    self.feedbackMessage = "Excellent pronunciation! 👍 Score: \(Int(score))/100"
                    self.feedbackColor = .green
                    self.hasPronounced = true
                } else if score > 60 {
                    self.feedbackMessage = "Good pronunciation. Score: \(Int(score))/100\n\(pronunciationResult.feedback)"
                    self.feedbackColor = .green
                    self.hasPronounced = true
                } else if score > 40 {
                    self.feedbackMessage = "Fair attempt. Score: \(Int(score))/100\n\(pronunciationResult.feedback)"
                    self.feedbackColor = .orange
                    self.hasPronounced = true
                } else {
                    self.feedbackMessage = "Needs improvement. Score: \(Int(score))/100\n\(pronunciationResult.feedback)"
                    self.feedbackColor = .red
                    self.hasPronounced = false
                }
                
                self.showFeedback = true
                
            case .failure(let error):
                // Handle error
                self.feedbackMessage = "Error: \(error.localizedDescription)"
                self.feedbackColor = .red
                self.showFeedback = true
            }
        }
    }
    
    // Save the object to Core Data
    private func saveObject(_ object: (english: String, chinese: String, pinyin: String)) {
        // Check if this object already exists in the collection
        let fetchRequest: NSFetchRequest<TaggedObject> = TaggedObject.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "english ==[c] %@", object.english)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if !results.isEmpty {
                // Object already exists, show feedback
                self.feedbackMessage = "'\(object.english)' already exists in your collection"
                self.feedbackColor = .orange
                self.showFeedback = true
                return
            }
            
            // Create a new TaggedObject in Core Data
            let newObject = TaggedObject(context: viewContext)
            newObject.english = object.english
            newObject.chinese = object.chinese
            newObject.pinyin = object.pinyin
            newObject.timestamp = Date()
            newObject.reviewCount = 0
            newObject.lastReviewDate = Date()
            
            // We don't have an image here, so we'll rely on the image saved by ARViewController
            // The ARViewController already saves the image when the object is first detected
            
            // Save the context
            try viewContext.save()
            print("Object saved: \(object.english)")
            
            // Show success feedback
            self.feedbackMessage = "'\(object.english)' added to your collection"
            self.feedbackColor = .green
            self.showFeedback = true
        } catch {
            print("Failed to save object: \(error)")
            
            // Show error feedback
            self.feedbackMessage = "Failed to save: \(error.localizedDescription)"
            self.feedbackColor = .red
            self.showFeedback = true
        }
    }
}

struct ARExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ARExploreView(isActive: true)
    }
} 