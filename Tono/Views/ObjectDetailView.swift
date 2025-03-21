import SwiftUI
import CoreData
import AVFoundation

struct ObjectDetailView: View {
    let object: TaggedObject
    @StateObject private var speechManager = SpeechManager()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 20) {
                // Object image
                if let imageData = object.image, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage.fixOrientation())
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                        .padding(.horizontal)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .foregroundColor(.gray)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                
                // Chinese character
                Text(object.chinese ?? "未知")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.red)
                
                // Pinyin
                Text(object.pinyin ?? "")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                // English translation
                Text(object.english ?? "Unknown")
                    .font(.title3)
                    .foregroundColor(.primary)
                    .padding(.bottom, 10)
                
                // Pronunciation button
                Button(action: {
                    speakWord(object.chinese ?? "")
                }) {
                    HStack {
                        Image(systemName: speechManager.isSpeaking ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 24))
                        Text(speechManager.isSpeaking ? "Speaking..." : "Pronounce")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: 200)
                    .background(speechManager.isSpeaking ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(speechManager.isSpeaking)
                
                // Review information
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Review Count:")
                        Spacer()
                        Text("\(object.reviewCount)")
                            .bold()
                    }
                    
                    HStack {
                        Text("Last Reviewed:")
                        Spacer()
                        if let date = object.lastReviewDate {
                            Text(dateFormatter.string(from: date))
                                .bold()
                        } else {
                            Text("Never")
                                .bold()
                        }
                    }
                    
                    HStack {
                        Text("Added:")
                        Spacer()
                        if let date = object.timestamp {
                            Text(dateFormatter.string(from: date))
                                .bold()
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(object.english ?? "Object Detail")
    }
    
    private func speakWord(_ word: String) {
        if word.isEmpty {
            return
        }
        
        speechManager.speak(word) { _ in
            // Speech completed or started
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}