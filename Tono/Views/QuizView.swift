import SwiftUI
import CoreData
import AVFoundation

// Quiz View for vocabulary practice
struct QuizView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    // Fetch objects for quiz
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaggedObject.lastReviewDate, ascending: true)],
        predicate: NSPredicate(format: "reviewCount >= 0"),
        animation: .default)
    private var allObjects: FetchedResults<TaggedObject>
    
    @State private var currentQuestionIndex = 0
    @State private var score = 0
    @State private var selectedAnswer: String? = nil
    @State private var showingFeedback = false
    @State private var isCorrect = false
    @State private var quizComplete = false
    @State private var quizQuestions: [QuizQuestion] = []
    
    // Speech synthesizer for pronunciation
    @StateObject private var speechManager = SpeechManager()
    
    // Maximum number of questions per quiz session
    private let maxQuestions = 10
    
    var body: some View {
        VStack {
            if quizComplete {
                // Quiz completion view
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("Quiz Complete!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your score: \(score)/\(quizQuestions.count)")
                        .font(.title2)
                    
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
            } else if quizQuestions.isEmpty {
                // No questions available
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Not enough items to create a quiz")
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
                // Current question
                let currentQuestion = quizQuestions[currentQuestionIndex]
                
                VStack {
                    // Progress indicator
                    ProgressView(value: Double(currentQuestionIndex + 1), total: Double(quizQuestions.count))
                        .padding(.horizontal)
                    
                    Text("Question \(currentQuestionIndex + 1) of \(quizQuestions.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                    
                    // Score
                    Text("Score: \(score)")
                        .font(.headline)
                        .padding(.top, 5)
                    
                    Spacer()
                    
                    // Question
                    if let imageData = currentQuestion.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .cornerRadius(10)
                            .padding()
                    }
                    
                    Text(currentQuestion.questionText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    // Answer options
                    VStack(spacing: 12) {
                        ForEach(currentQuestion.options.indices, id: \.self) { index in
                            let option = currentQuestion.options[index]
                            let pinyin = index < currentQuestion.optionsPinyin.count ? currentQuestion.optionsPinyin[index] : ""
                            
                            Button(action: {
                                if !showingFeedback {
                                    selectedAnswer = option
                                    isCorrect = (option == currentQuestion.correctAnswer)
                                    showingFeedback = true
                                    
                                    // Update score
                                    if isCorrect {
                                        score += 1
                                    }
                                    
                                    // Update SRS data
                                    if let object = currentQuestion.object {
                                        PersistenceController.shared.updateReviewStatus(
                                            for: object,
                                            wasCorrect: isCorrect,
                                            context: viewContext
                                        )
                                    }
                                }
                            }) {
                                HStack {
                                    // Option text with pinyin
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option)
                                            .font(.headline)
                                        
                                        Text(pinyin)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 8)
                                    
                                    Spacer()
                                    
                                    // Audio button
                                    Button(action: {
                                        speakText(option)
                                    }) {
                                        Image(systemName: speechManager.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                            .foregroundColor(.blue)
                                            .padding(8)
                                            .background(Color.blue.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    .disabled(speechManager.isSpeaking)
                                }
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity)
                                .background(
                                    Group {
                                        if showingFeedback {
                                            if option == currentQuestion.correctAnswer {
                                                Color.green.opacity(0.2)
                                            } else if option == selectedAnswer {
                                                Color.red.opacity(0.2)
                                            } else {
                                                Color(.systemGray6)
                                            }
                                        } else {
                                            Color(.systemGray6)
                                        }
                                    }
                                )
                                .foregroundColor(
                                    showingFeedback && option == currentQuestion.correctAnswer ? .green : .primary
                                )
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            showingFeedback && option == selectedAnswer ? 
                                                (isCorrect ? Color.green : Color.red) : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Next button
                    if showingFeedback {
                        Button(action: {
                            // Move to next question or complete quiz
                            if currentQuestionIndex < quizQuestions.count - 1 {
                                currentQuestionIndex += 1
                                selectedAnswer = nil
                                showingFeedback = false
                            } else {
                                quizComplete = true
                            }
                        }) {
                            Text(currentQuestionIndex < quizQuestions.count - 1 ? "Next Question" : "Finish Quiz")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationTitle("Vocabulary Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            prepareQuizQuestions()
        }
    }
    
    // Speak the text using text-to-speech
    private func speakText(_ text: String) {
        speechManager.speak(text) { _ in
            // We don't need to update isPlayingAudio anymore as we'll use speechManager.isSpeaking
        }
    }
    
    // Prepare quiz questions from available objects
    private func prepareQuizQuestions() {
        // Convert FetchedResults to Array for easier manipulation
        let objects = Array(allObjects)
        
        // Check if we have enough objects
        if objects.count < 4 {
            // Need at least 4 objects to create multiple choice questions
            quizQuestions = []
            return
        }
        
        // Determine how many questions to create
        let questionCount = min(maxQuestions, objects.count)
        
        // Create shuffled copy of objects to use for questions
        var shuffledObjects = objects.shuffled()
        
        // Create questions
        var questions: [QuizQuestion] = []
        
        for i in 0..<questionCount {
            // Get the target object for this question
            let targetObject = shuffledObjects[i % shuffledObjects.count]
            
            // Create a pool of other objects to use as distractors
            var distractors = objects.filter { $0 != targetObject }.shuffled()
            
            // Ensure we have at least 3 distractors
            while distractors.count < 3 {
                distractors.append(distractors[distractors.count % distractors.count])
            }
            
            // Take the first 3 distractors
            let selectedDistractors = Array(distractors.prefix(3))
            
            // Create options array with all objects (target + distractors)
            var allOptionsObjects = selectedDistractors
            allOptionsObjects.append(targetObject)
            
            // Shuffle the objects
            allOptionsObjects.shuffle()
            
            // Extract Chinese and Pinyin from the objects
            let options = allOptionsObjects.compactMap { $0.chinese }
            let optionsPinyin = allOptionsObjects.compactMap { $0.pinyin }
            
            // Create the question
            let question = QuizQuestion(
                questionText: "What is the Chinese word for '\(targetObject.english ?? "unknown")'?",
                options: options,
                optionsPinyin: optionsPinyin,
                correctAnswer: targetObject.chinese ?? "未知",
                imageData: targetObject.image,
                object: targetObject
            )
            
            questions.append(question)
        }
        
        quizQuestions = questions
    }
} 