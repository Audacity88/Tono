import SwiftUI
import CoreData

// Modern color palette
struct ModernColors {
    static let teal = Color(red: 0.18, green: 0.8, blue: 0.75)
    static let coral = Color(red: 1.0, green: 0.4, blue: 0.38)
    static let indigo = Color(red: 0.35, green: 0.34, blue: 0.84)
    static let amber = Color(red: 1.0, green: 0.75, blue: 0.27)
    static let mint = Color(red: 0.24, green: 0.78, blue: 0.63)
    
    // Gradients
    static let tealGradient = LinearGradient(
        gradient: Gradient(colors: [teal, teal.opacity(0.7)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let coralGradient = LinearGradient(
        gradient: Gradient(colors: [coral, coral.opacity(0.7)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let indigoGradient = LinearGradient(
        gradient: Gradient(colors: [indigo, indigo.opacity(0.7)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// Practice View with navigation to different practice modes
struct PracticeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var navigateToQuiz = false
    @State private var animateCards = false
    
    // Fetch objects due for review - prioritize newer cards first
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaggedObject.timestamp, ascending: false)],
        predicate: NSPredicate(format: "reviewCount >= 0"),
        animation: .default)
    private var reviewObjects: FetchedResults<TaggedObject>
    
    // Background color based on color scheme
    private var backgroundColor: Color {
        return colorScheme == .dark ? Color.black : Color(red: 0.97, green: 0.97, blue: 0.97)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundColor
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("Practice Mode")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .padding(.top)
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : -20)
                        .animation(.easeOut(duration: 0.5), value: animateCards)
                    
                    if reviewObjects.isEmpty {
                        VStack(spacing: 25) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 70))
                                .foregroundColor(ModernColors.coral)
                                .padding()
                                .background(
                                    Circle()
                                        .fill(ModernColors.coral.opacity(0.2))
                                        .frame(width: 150, height: 150)
                                )
                                .scaleEffect(animateCards ? 1 : 0.8)
                                .opacity(animateCards ? 1 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: animateCards)
                            
                            Text("No objects to review")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .opacity(animateCards ? 1 : 0)
                                .animation(.easeOut(duration: 0.5).delay(0.2), value: animateCards)
                            
                            Text("Explore your surroundings and tag objects to add them to your practice queue")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .foregroundColor(.secondary)
                                .opacity(animateCards ? 1 : 0)
                                .animation(.easeOut(duration: 0.5).delay(0.3), value: animateCards)
                        }
                        .padding(.top, 50)
                    } else {
                        ScrollView {
                            VStack(spacing: 22) {
                                // Quiz Card
                                NavigationLink(destination: QuizView()) {
                                    PracticeCard(
                                        title: "Vocabulary Quiz",
                                        description: "Test your knowledge with multiple choice questions",
                                        iconName: "questionmark.circle",
                                        gradient: ModernColors.indigoGradient,
                                        count: reviewObjects.count
                                    )
                                }
                                .buttonStyle(CardButtonStyle())
                                .offset(x: animateCards ? 0 : -300)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: animateCards)
                                
                                // Flashcard Card
                                NavigationLink(destination: FlashcardView()) {
                                    PracticeCard(
                                        title: "Flashcards",
                                        description: "Review vocabulary with spaced repetition",
                                        iconName: "rectangle.stack",
                                        gradient: ModernColors.coralGradient,
                                        count: reviewObjects.count
                                    )
                                }
                                .buttonStyle(CardButtonStyle())
                                .offset(x: animateCards ? 0 : -300)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: animateCards)
                                
                                // Pronunciation Card
                                NavigationLink(destination: PronunciationPracticeView()) {
                                    PracticeCard(
                                        title: "Pronunciation Practice",
                                        description: "Practice speaking Chinese words and get feedback",
                                        iconName: "waveform",
                                        gradient: ModernColors.tealGradient,
                                        count: reviewObjects.count
                                    )
                                }
                                .buttonStyle(CardButtonStyle())
                                .offset(x: animateCards ? 0 : -300)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: animateCards)
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                        }
                    }
                    
                    Spacer()
                }
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    // Trigger animations when view appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            animateCards = true
                        }
                    }
                }
                .onDisappear {
                    // Reset animation state when view disappears
                    animateCards = false
                }
            }
        }
    }
}

// Custom button style for cards with animation
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Card view for practice options
struct PracticeCard: View {
    let title: String
    let description: String
    let iconName: String
    let gradient: LinearGradient
    let count: Int
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    var body: some View {
        HStack {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(gradient)
                    .frame(width: 70, height: 70)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                
                Image(systemName: iconName)
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            .padding(.trailing, 15)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text("\(count) items")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                        )
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 5)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)
    }
} 