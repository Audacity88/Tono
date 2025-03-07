// MissingTranslationsView.swift
// Tono
//
// Created as part of the AR Gamified Chinese Learning App

import SwiftUI

struct MissingTranslationsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var missingTranslations: [String] = []
    
    var body: some View {
        NavigationView {
            VStack {
                if missingTranslations.isEmpty {
                    // Custom empty state view instead of ContentUnavailableView (iOS 17+)
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("No Missing Translations")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("All YOLO classes have translations.")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(missingTranslations, id: \.self) { word in
                            Text(word)
                        }
                    }
                }
            }
            .navigationTitle("Missing Translations")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                checkMissingTranslations()
            }
        }
    }
    
    private func checkMissingTranslations() {
        // Get all YOLO class labels
        let yoloLabels = YOLOv8ObjectDetector.shared.getClassLabels()
        
        // Check which ones are missing translations
        let translationManager = TranslationManager.shared
        
        missingTranslations = yoloLabels.filter { label in
            translationManager.getTranslation(for: label) == nil
        }
    }
} 