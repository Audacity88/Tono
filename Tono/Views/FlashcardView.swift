import SwiftUI
import CoreData

// Flashcard View for spaced repetition practice
struct FlashcardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    
    // Fetch objects for flashcards - prioritize newer cards first
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaggedObject.timestamp, ascending: false)],
        predicate: NSPredicate(format: "reviewCount >= 0"),
        animation: .default)
    private var reviewObjects: FetchedResults<TaggedObject>
    
    @State private var currentIndex = 0
    @State private var isShowingAnswer = false
    @State private var offset = CGSize.zero
    @State private var flashcards: [TaggedObject] = []
    @State private var sessionComplete = false
    @State private var correctCount = 0
    @State private var incorrectCount = 0
    @StateObject private var speechManager = SpeechManager()
    
    // Maximum number of cards per session
    private let maxCards = 10
    
    // Computed property for pinyin text color
    private var pinyinColor: Color {
        return colorScheme == .dark ? Color.cyan : Color.blue
    }
    
    var body: some View {
        VStack {
            if sessionComplete {
                // Session completion view
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("Session Complete!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("You reviewed \(flashcards.count) cards")
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
            } else if flashcards.isEmpty {
                // No flashcards available
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("No flashcards available")
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
                // Current flashcard
                VStack {
                    // Progress indicator
                    ProgressView(value: Double(currentIndex + 1), total: Double(flashcards.count))
                        .padding(.horizontal)
                    
                    Text("Card \(currentIndex + 1) of \(flashcards.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                    
                    Spacer()
                    
                    // Flashcard
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .shadow(radius: 10)
                            .frame(width: 320, height: 420)
                        
                        VStack(spacing: 15) {
                            // Always show the Chinese character
                            Text(flashcards[currentIndex].chinese ?? "未知")
                                .font(.system(size: 60, weight: .bold))
                                .foregroundColor(.red)
                                .padding(.top, 20)
                            
                            // Always show the pinyin with pronunciation button
                            HStack(spacing: 8) {
                                Text(flashcards[currentIndex].pinyin ?? "")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(pinyinColor)
                                
                                Button(action: {
                                    speakChinese(flashcards[currentIndex].chinese ?? "")
                                }) {
                                    Image(systemName: speechManager.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                        .padding(6)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .disabled(speechManager.isSpeaking)
                            }
                            .padding(.bottom, 10)
                            
                            Divider()
                                .padding(.horizontal, 30)
                            
                            if isShowingAnswer {
                                // Show the image
                                if let imageData = flashcards[currentIndex].image, let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage.rotate90DegreesClockwise() ?? uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 120)
                                        .cornerRadius(10)
                                        .padding(.top, 10)
                                }
                                
                                // English meaning
                                Text(flashcards[currentIndex].english ?? "unknown")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .padding(.top, 5)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.8)
                            } else {
                                Spacer()
                                    .frame(height: 120)
                                
                                Button(action: {
                                    withAnimation {
                                        isShowingAnswer = true
                                    }
                                }) {
                                    Text("Show English")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(width: 200)
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }
                                .padding(.bottom, 20)
                            }
                        }
                        .padding(20)
                    }
                    .offset(x: offset.width, y: 0)
                    .rotationEffect(.degrees(Double(offset.width / 20)))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                if isShowingAnswer {
                                    self.offset = gesture.translation
                                }
                            }
                            .onEnded { gesture in
                                if isShowingAnswer {
                                    withAnimation {
                                        if gesture.translation.width > 100 {
                                            // Correct - swipe right
                                            self.offset = CGSize(width: 500, height: 0)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                self.nextCard(wasCorrect: true)
                                            }
                                        } else if gesture.translation.width < -100 {
                                            // Incorrect - swipe left
                                            self.offset = CGSize(width: -500, height: 0)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                self.nextCard(wasCorrect: false)
                                            }
                                        } else {
                                            self.offset = .zero
                                        }
                                    }
                                }
                            }
                    )
                    
                    Spacer()
                    
                    if isShowingAnswer {
                        HStack(spacing: 50) {
                            // Incorrect button
                            Button(action: {
                                withAnimation {
                                    self.offset = CGSize(width: -500, height: 0)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        self.nextCard(wasCorrect: false)
                                    }
                                }
                            }) {
                                VStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.red)
                                    Text("Incorrect")
                                        .font(.caption)
                                }
                            }
                            
                            // Correct button
                            Button(action: {
                                withAnimation {
                                    self.offset = CGSize(width: 500, height: 0)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        self.nextCard(wasCorrect: true)
                                    }
                                }
                            }) {
                                VStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.green)
                                    Text("Correct")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.bottom, 30)
                    }
                    
                    Text("Swipe right if you know it, left if you don't")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                        .opacity(isShowingAnswer ? 1 : 0)
                }
            }
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            prepareFlashcards()
        }
    }
    
    // Speak the Chinese text
    private func speakChinese(_ text: String) {
        if text.isEmpty {
            return
        }
        
        speechManager.speak(text) { _ in
            // Speech completed or started
        }
    }
    
    // Prepare flashcards from available objects
    private func prepareFlashcards() {
        // Convert FetchedResults to Array for easier manipulation
        let objects = Array(reviewObjects)
        
        if objects.isEmpty {
            flashcards = []
            return
        }
        
        // Take up to maxCards objects, prioritizing the newest ones
        flashcards = Array(objects.prefix(maxCards))
    }
    
    // Move to the next card
    private func nextCard(wasCorrect: Bool) {
        // Update SRS data
        let currentObject = flashcards[currentIndex]
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
        
        // Reset for next card
        if currentIndex < flashcards.count - 1 {
            currentIndex += 1
            isShowingAnswer = false
            offset = .zero
        } else {
            sessionComplete = true
        }
    }
} 