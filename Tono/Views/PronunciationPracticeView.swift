import SwiftUI
import CoreData
import AVFoundation

// Pronunciation Practice View
struct PronunciationPracticeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    // Fetch objects for pronunciation practice - prioritize newer cards first
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaggedObject.timestamp, ascending: false)],
        predicate: NSPredicate(format: "reviewCount >= 0"),
        animation: .default)
    private var reviewObjects: FetchedResults<TaggedObject>
    
    @State private var currentIndex = 0
    @State private var practiceObjects: [TaggedObject] = []
    @State private var isRecording = false
    @State private var feedbackMessage = ""
    @State private var feedbackColor = Color.gray
    @State private var showFeedback = false
    @State private var sessionComplete = false
    @State private var correctCount = 0
    @State private var incorrectCount = 0
    
    // Maximum number of items per session
    private let maxItems = 10
    
    // Audio session properties
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    
    // Pronunciation API
    @StateObject private var pronunciationAPI = PronunciationAPI()
    
    // Speech manager for text-to-speech
    @StateObject private var speechManager = SpeechManager()
    
    var body: some View {
        VStack {
            if sessionComplete {
                // Session completion view
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("Practice Complete!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("You practiced \(practiceObjects.count) words")
                        .font(.title2)
                    
                    HStack(spacing: 30) {
                        VStack {
                            Text("\(correctCount)")
                                .font(.title)
                                .foregroundColor(.green)
                            Text("Correct")
                                .font(.subheadline)
                        }
                        
                        VStack {
                            Text("\(incorrectCount)")
                                .font(.title)
                                .foregroundColor(.red)
                            Text("Incorrect")
                                .font(.subheadline)
                        }
                    }
                    .padding()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Return to Practice")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
                .padding()
            } else if practiceObjects.isEmpty {
                // No practice items available
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("No words available for practice")
                        .font(.headline)
                    
                    Text("Explore more objects to build your vocabulary")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Return to Practice")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
                .padding()
            } else {
                // Current practice item
                VStack {
                    // Progress indicator
                    ProgressView(value: Double(currentIndex + 1), total: Double(practiceObjects.count))
                        .padding(.horizontal)
                    
                    Text("Word \(currentIndex + 1) of \(practiceObjects.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                    
                    Spacer()
                    
                    // Practice card
                    VStack(spacing: 20) {
                        if let imageData = practiceObjects[currentIndex].image, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage.rotate90DegreesClockwise() ?? uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .cornerRadius(10)
                                .padding()
                        }
                        
                        Text(practiceObjects[currentIndex].english ?? "unknown")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text(practiceObjects[currentIndex].chinese ?? "未知")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.red)
                        
                        HStack(spacing: 8) {
                            Text(practiceObjects[currentIndex].pinyin ?? "")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                if let chinese = practiceObjects[currentIndex].chinese {
                                    speechManager.speak(chinese) { _ in }
                                }
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
                        .padding(.bottom, 10)
                        
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
                                    .frame(width: 80, height: 80)
                                
                                if isRecording {
                                    Circle()
                                        .stroke(Color.red, lineWidth: 4)
                                        .frame(width: 90, height: 90)
                                }
                                
                                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            }
                        }
                        .disabled(pronunciationAPI.isProcessing)
                        .padding()
                        
                        // Loading indicator during API processing
                        if pronunciationAPI.isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.5)
                                .padding()
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
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding()
                    
                    Spacer()
                    
                    // Navigation buttons
                    if showFeedback {
                        HStack(spacing: 30) {
                            // Skip button
                            Button(action: {
                                moveToNextWord(wasCorrect: false)
                            }) {
                                Text("Skip")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(width: 120)
                                    .background(Color.gray)
                                    .cornerRadius(10)
                            }
                            
                            // Next button
                            Button(action: {
                                moveToNextWord(wasCorrect: feedbackColor == .green)
                            }) {
                                Text("Next")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(width: 120)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationTitle("Pronunciation Practice")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupAudioSession()
            preparePracticeItems()
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
    
    // Prepare practice items from available objects
    private func preparePracticeItems() {
        // Convert FetchedResults to Array for easier manipulation
        let objects = Array(reviewObjects)
        
        if objects.isEmpty {
            practiceObjects = []
            return
        }
        
        // Take up to maxItems objects, prioritizing the newest ones
        practiceObjects = Array(objects.prefix(maxItems))
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
        // Create a temporary URL for the recording
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("pronunciation_recording.m4a")
        
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
        guard let recordingURL = recordingURL, let chineseText = practiceObjects[currentIndex].chinese else {
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
                } else if score > 60 {
                    self.feedbackMessage = "Good pronunciation. Score: \(Int(score))/100\n\(pronunciationResult.feedback)"
                    self.feedbackColor = .green
                } else if score > 40 {
                    self.feedbackMessage = "Fair attempt. Score: \(Int(score))/100\n\(pronunciationResult.feedback)"
                    self.feedbackColor = .orange
                } else {
                    self.feedbackMessage = "Needs improvement. Score: \(Int(score))/100\n\(pronunciationResult.feedback)"
                    self.feedbackColor = .red
                }
                
                // Show detailed feedback if available
                if let details = pronunciationResult.details, let errors = details.specificErrors, !errors.isEmpty {
                    self.feedbackMessage += "\n• " + errors.joined(separator: "\n• ")
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
    
    // Move to the next word
    private func moveToNextWord(wasCorrect: Bool) {
        // Update SRS data
        let currentObject = practiceObjects[currentIndex]
        PersistenceController.shared.updateReviewStatus(
            for: currentObject,
            wasCorrect: wasCorrect,
            context: viewContext
        )
        
        // Update counters
        if wasCorrect {
            correctCount += 1
        } else {
            incorrectCount += 1
        }
        
        // Reset for next word
        if currentIndex < practiceObjects.count - 1 {
            currentIndex += 1
            showFeedback = false
        } else {
            sessionComplete = true
        }
    }
}

// Alert item for error messages
struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
} 