import SwiftUI
import CoreData

// Practice View with navigation to different practice modes
struct PracticeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var navigateToQuiz = false
    
    // Fetch objects due for review
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaggedObject.lastReviewDate, ascending: true)],
        predicate: NSPredicate(format: "reviewCount >= 0"),
        animation: .default)
    private var reviewObjects: FetchedResults<TaggedObject>
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Practice Mode")
                    .font(.largeTitle)
                    .padding()
                
                if reviewObjects.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No objects to review")
                            .font(.headline)
                        
                        Text("Explore your surroundings and tag objects to add them to your practice queue")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    VStack(spacing: 25) {
                        // Quiz Card
                        NavigationLink(destination: QuizView()) {
                            PracticeCard(
                                title: "Vocabulary Quiz",
                                description: "Test your knowledge with multiple choice questions",
                                iconName: "questionmark.circle",
                                color: .blue,
                                count: reviewObjects.count
                            )
                        }
                        
                        // Pronunciation Card
                        NavigationLink(destination: PronunciationPracticeView()) {
                            PracticeCard(
                                title: "Pronunciation Practice",
                                description: "Practice speaking Chinese words and get feedback",
                                iconName: "waveform",
                                color: .purple,
                                count: reviewObjects.count
                            )
                        }
                        
                        // Flashcard Card
                        NavigationLink(destination: FlashcardView()) {
                            PracticeCard(
                                title: "Flashcards",
                                description: "Review vocabulary with spaced repetition",
                                iconName: "rectangle.stack",
                                color: .orange,
                                count: reviewObjects.count
                            )
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Practice")
        }
    }
}

// Card view for practice options
struct PracticeCard: View {
    let title: String
    let description: String
    let iconName: String
    let color: Color
    let count: Int
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.system(size: 30))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(color)
                .cornerRadius(15)
                .padding(.trailing, 10)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text("\(count) items to review")
                    .font(.caption)
                    .foregroundColor(color)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
} 