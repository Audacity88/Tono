// TranslationManager.swift
// Tono
//
// Created as part of the AR Gamified Chinese Learning App

import Foundation

struct TranslationItem: Codable {
    let english: String
    let chinese: String
    let pinyin: String
    let category: String
}

struct TranslationData: Codable {
    let objects: [TranslationItem]
}

class TranslationManager {
    static let shared = TranslationManager()
    
    private var translationData: TranslationData?
    private var translationDictionary: [String: (chinese: String, pinyin: String)] = [:]
    
    private init() {
        loadTranslations()
    }
    
    private func loadTranslations() {
        // First try to load from the bundle
        if let url = Bundle.main.url(forResource: "translations", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                translationData = try JSONDecoder().decode(TranslationData.self, from: data)
                buildDictionary()
                print("Successfully loaded translations from bundle")
            } catch {
                print("Error loading translations from bundle: \(error)")
                loadFallbackTranslations()
            }
        } else {
            print("Translations file not found in bundle")
            loadFallbackTranslations()
        }
    }
    
    private func loadFallbackTranslations() {
        // Try to load from the Resources directory
        let paths = [
            Bundle.main.bundlePath + "/Resources/translations.json",
            Bundle.main.bundlePath + "/../Resources/translations.json"
        ]
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: path))
                    translationData = try JSONDecoder().decode(TranslationData.self, from: data)
                    buildDictionary()
                    print("Successfully loaded translations from \(path)")
                    return
                } catch {
                    print("Error loading translations from \(path): \(error)")
                }
            }
        }
        
        // If all else fails, use hardcoded fallback translations
        print("Using hardcoded fallback translations")
        setupFallbackTranslations()
    }
    
    private func buildDictionary() {
        guard let objects = translationData?.objects else { return }
        
        // Build a dictionary for quick lookups
        for object in objects {
            translationDictionary[object.english.lowercased()] = (chinese: object.chinese, pinyin: object.pinyin)
        }
        
        print("Built translation dictionary with \(translationDictionary.count) entries")
    }
    
    private func setupFallbackTranslations() {
        // Hardcoded fallback translations (minimal set)
        translationDictionary = [
            "apple": ("苹果", "píng guǒ"),
            "chair": ("椅子", "yǐ zi"),
            "table": ("桌子", "zhuō zi"),
            "book": ("书", "shū"),
            "cup": ("杯子", "bēi zi"),
            "bottle": ("瓶子", "píng zi"),
            "laptop": ("笔记本电脑", "bǐ jì běn diàn nǎo"),
            "phone": ("手机", "shǒu jī"),
            "person": ("人", "rén"),
            "dog": ("狗", "gǒu"),
            "cat": ("猫", "māo")
        ]
    }
    
    // Get translation for an object name
    func getTranslation(for objectName: String) -> (chinese: String, pinyin: String)? {
        return translationDictionary[objectName.lowercased()]
    }
    
    // Get all translations
    func getAllTranslations() -> [String: (chinese: String, pinyin: String)] {
        return translationDictionary
    }
    
    // Get translations by category
    func getTranslations(forCategory category: String) -> [TranslationItem] {
        return translationData?.objects.filter { $0.category == category } ?? []
    }
    
    // Get all categories
    func getAllCategories() -> [String] {
        let categories = translationData?.objects.map { $0.category } ?? []
        return Array(Set(categories)).sorted()
    }
} 