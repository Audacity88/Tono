import SwiftUI
import CoreData

// Flashcard View for spaced repetition practice
struct FlashcardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    // Fetch objects for flashcards
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaggedObject.lastReviewDate, ascending: true)],
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
    
    // Maximum number of cards per session
    private let maxCards = 10
    
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
                            .frame(width: 300, height: 400)
                        
                        VStack(spacing: 20) {
                            if let imageData = flashcards[currentIndex].image, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 150)
                                    .cornerRadius(10)
                            }
                            
                            if isShowingAnswer {
                                Text(flashcards[currentIndex].chinese ?? "未知")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.red)
                                
                                Text(flashcards[currentIndex].pinyin ?? "")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(flashcards[currentIndex].english ?? "unknown")
                                    .font(.system(size: 36, weight: .bold))
                            }
                            
                            if !isShowingAnswer {
                                Button(action: {
                                    withAnimation {
                                        isShowingAnswer = true
                                    }
                                }) {
                                    Text("Show Answer")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(width: 200)
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding(30)
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
    
    // Prepare flashcards from available objects
    private func prepareFlashcards() {
        // Convert FetchedResults to Array for easier manipulation
        let objects = Array(reviewObjects)
        
        if objects.isEmpty {
            flashcards = []
            return
        }
        
        // Take up to maxCards objects, prioritizing those that haven't been reviewed recently
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