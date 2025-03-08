import Foundation
import AVFoundation
import Combine

/// API client for thefluent.me pronunciation assessment service
class PronunciationAPI: ObservableObject {
    // API endpoint - using correct RapidAPI URL
    private let baseURL = "https://thefluent-me.p.rapidapi.com"
    
    // API key - should be stored securely in a real app
    private var apiKey: String = ""
    
    // Language IDs for thefluent.me API
    public enum LanguageID {
        static let english = 22
        static let chineseSimplified = 13  // Mandarin Chinese
        static let chineseTraditional = 14 // Cantonese
    }
    
    // Current language ID to use
    @Published var currentLanguageID: Int = UserDefaults.standard.integer(forKey: "FluentLanguageID") != 0 ? 
        UserDefaults.standard.integer(forKey: "FluentLanguageID") : LanguageID.english // Default to English for testing
    
    // Published properties for UI updates
    @Published var isProcessing = false
    @Published var lastScore: Double = 0
    @Published var lastFeedback: String = ""
    @Published var error: String? = nil
    @Published var supportedLanguages: [LanguageInfo] = []
    
    // Simulated mode for testing without API key
    private var simulationMode = false
    
    init() {
        // Load API key from UserDefaults or environment
        if let savedKey = UserDefaults.standard.string(forKey: "FluentAPIKey"), !savedKey.isEmpty {
            self.apiKey = savedKey
            self.simulationMode = false
        } else if let key = ProcessInfo.processInfo.environment["FLUENT_API_KEY"] {
            self.apiKey = key
            self.simulationMode = false
        } else {
            // If no API key is available, use simulation mode
            self.simulationMode = true
        }
        
        // Always enable simulation mode for now until we get the API working
        print("API Key: \(apiKey)")
        print("Simulation Mode: \(simulationMode)")
    }
    
    /// Set API key manually
    func setAPIKey(_ key: String) {
        self.apiKey = key
        self.simulationMode = key.isEmpty
        
        // Print for debugging
        print("API Key set to: \(key)")
        print("Simulation Mode: \(simulationMode)")
    }
    
    /// Set the language ID to use for pronunciation assessment
    func setLanguageID(_ id: Int) {
        self.currentLanguageID = id
        UserDefaults.standard.set(id, forKey: "FluentLanguageID")
    }
    
    /// Fetch supported languages from the API
    func fetchSupportedLanguages(completion: @escaping (Result<[LanguageInfo], Error>) -> Void) {
        // Always use simulation mode for languages
        let languages = [
            LanguageInfo(language_id: LanguageID.english, language_name: "English", language_voice: "English (US) - female voice"),
            LanguageInfo(language_id: LanguageID.chineseSimplified, language_name: "Chinese (Simplified)", language_voice: "Chinese (Mainland) - female voice"),
            LanguageInfo(language_id: LanguageID.chineseTraditional, language_name: "Chinese (Traditional)", language_voice: "Chinese (Hong Kong) - female voice")
        ]
        self.supportedLanguages = languages
        completion(.success(languages))
        return
    }
    
    /// Assess pronunciation by comparing audio recording to expected text
    /// - Parameters:
    ///   - audioURL: URL to the audio recording
    ///   - text: Expected text
    ///   - completion: Callback with assessment result
    func assessPronunciation(audioURL: URL, text: String, completion: @escaping (Result<PronunciationResult, Error>) -> Void) {
        // Set processing state
        self.isProcessing = true
        self.error = nil
        
        // Always use simulation mode for now
        // Simulate processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            // Generate random score between 50-95
            let score = Double.random(in: 50...95)
            
            // Create feedback based on language
            var feedback = ""
            if self?.currentLanguageID == LanguageID.chineseSimplified || self?.currentLanguageID == LanguageID.chineseTraditional {
                feedback = "模拟得分: \(Int(score))/100\n文本: \"\(text)\""
            } else {
                feedback = "Simulated score: \(Int(score))/100\nText: \"\(text)\""
            }
            
            let result = PronunciationResult(
                score: score,
                feedback: feedback,
                details: PronunciationDetails(
                    toneAccuracy: Double.random(in: 60...90),
                    fluency: Double.random(in: 60...90),
                    phonemeAccuracy: Double.random(in: 60...90),
                    specificErrors: []
                )
            )
            
            self?.isProcessing = false
            self?.lastScore = result.score
            self?.lastFeedback = result.feedback
            completion(.success(result))
        }
    }
    
    // Generate feedback message from API response
    private func generateFeedback(from response: FluentAPIResponse) -> String {
        let score = response.score.overall_points
        let recognizedWords = response.score.number_of_recognized_words
        let totalWords = response.score.number_of_words_in_post
        
        var feedback = "Score: \(Int(score))/90"
        
        if recognizedWords < totalWords {
            feedback += "\nRecognized \(recognizedWords) of \(totalWords) words"
        }
        
        if let transcript = response.score.user_recording_transcript, !transcript.isEmpty {
            feedback += "\nTranscript: \"\(transcript)\""
        }
        
        return feedback
    }
}

/// Model for pronunciation assessment result (internal use)
struct PronunciationResult: Codable {
    let score: Double
    let feedback: String
    let details: PronunciationDetails?
}

/// Detailed pronunciation assessment information (internal use)
struct PronunciationDetails: Codable {
    let toneAccuracy: Double?
    let fluency: Double?
    let phonemeAccuracy: Double?
    let specificErrors: [String]?
}

/// Response model from thefluent.me API
struct FluentAPIResponse: Codable {
    let score: ScoreData
}

/// Score data from thefluent.me API
struct ScoreData: Codable {
    let ai_reading: String
    let audio_provided: String
    let length_of_recording_in_sec: Double
    let number_of_recognized_words: Int
    let number_of_words_in_post: Int
    let overall_points: Double
    let post_language_id: Int
    let post_language_name: String
    let post_provided: String
    let post_title: String
    let score_date: String
    let score_id: String
    let user_recording_transcript: String?
}

/// Language information from thefluent.me API
struct LanguageInfo: Codable, Identifiable {
    let language_id: Int
    let language_name: String
    let language_voice: String
    
    var id: Int { language_id }
}

/// Response for language list from thefluent.me API
struct LanguageResponse: Codable {
    let supported_languages: [LanguageInfo]
} 