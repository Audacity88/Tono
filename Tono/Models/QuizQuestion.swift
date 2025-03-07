import Foundation
import CoreData

// Quiz question model
struct QuizQuestion {
    let questionText: String
    let options: [String]
    let optionsPinyin: [String]
    let correctAnswer: String
    let imageData: Data?
    let object: TaggedObject?
    
    // Helper method to get pinyin for a given option
    func getPinyin(for option: String) -> String {
        if let index = options.firstIndex(of: option) {
            return optionsPinyin[index]
        }
        return ""
    }
} 