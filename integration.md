# Tono + YOLO iOS App Integration Checklist

This document outlines the step-by-step process for integrating the functionality of the Tono app into the YOLO iOS app framework.

## Phase 1: Project Setup and Analysis

- [x] **Create a backup of both projects**
  - Create a backup of the original Tono app
  - Create a backup of the original YOLO iOS app

- [x] **Analyze both codebases thoroughly**
  - Document the architecture of Tono (SwiftUI-based)
    - SwiftUI-based UI with TabView navigation
    - Core Data for persistence
    - ARKit for object recognition
    - AVFoundation for audio recording and playback
    - SpeechManager for text-to-speech
    - PronunciationAPI for pronunciation feedback
  - Document the architecture of YOLO iOS app (UIKit-based)
    - UIKit with Storyboards for UI
    - AVFoundation for camera access
    - Vision and CoreML for object detection
    - UIKit-based visualization of detection results
  - Identify shared components and potential integration points
    - Camera and video processing
    - Object detection pipeline
    - UI components that need to be merged

- [x] **Set up a new branch for integration work**
  - Create a new branch from the YOLO iOS app repository (created 'tono-integration' branch)
  - Ensure all YOLO models are properly included (verified models in YOLO/Models directory)

## Phase 2: Core Functionality Migration

- [x] **Integrate Core Data model from Tono**
  - Copy the Tono.xcdatamodeld to the YOLO project
  - Create a Persistence.swift file in YOLO project based on Tono's implementation
  - Add the TaggedObject entity and related methods
  - Test Core Data functionality in the YOLO app

- [x] **Implement language learning utilities**
  - Create a Utilities folder in the YOLO project
  - Add SpeechManager.swift for text-to-speech functionality
  - Add PronunciationAPI.swift for pronunciation assessment
  - Add TranslationManager.swift for object translations
  - Test each utility independently

- [x] **Modify YOLO object detection to support language learning**
  - Create a translation database (JSON or plist) with English-Chinese-Pinyin mappings for COCO classes
  - Modify the YOLO detection pipeline in ViewController.swift to include translations
  - Add methods to look up translations for detected objects
  - Test detection with translations

## Phase 3: UI Integration

- [x] **Decide on UI framework approach**
  - Option 1: Keep UIKit base and integrate SwiftUI views using UIHostingController ✓
    - This approach minimizes changes to the YOLO detection pipeline
    - Allows reuse of Tono's SwiftUI views with minimal modifications
    - Requires bridging between UIKit and SwiftUI

- [x] **Implement tab-based navigation**
  - Create a custom UITabBarController in the YOLO app
  - Set up the first tab with the existing YOLO ViewController
  - Create UIHostingControllers for SwiftUI-based tabs:
    - CollectionViewController (hosting CollectionView)
    - PracticeViewController (hosting PracticeView)
    - SettingsViewController (hosting SettingsView)
  - Implement tab switching logic

- [x] **Implement detection popup**
  - Create a SwiftUI overlay view for detected objects
  - Implement a UIHostingController to present the overlay
  - Add translation display to the popup
  - Add pronunciation recording and feedback UI
  - Ensure proper layout in both portrait and landscape orientations

## Phase 4: Feature Implementation

- [x] **Collection Feature**
  - Implement the CollectionView as a SwiftUI view
  - Create a UIHostingController to present it in the UIKit app
  - Add functionality to save detected objects to Core Data
  - Implement filtering and sorting capabilities
  - Test saving and retrieving objects

- [x] **Practice Feature**
  - Implement the PracticeView with its sub-components:
    - FlashcardView for flashcard practice (placeholder implemented)
    - QuizView for quiz-based learning (placeholder implemented)
    - PronunciationPracticeView for pronunciation practice (placeholder implemented)
  - Create a UIHostingController to present it in the UIKit app
  - Ensure practice features work with collected objects
  - Test all practice modes

- [x] **Settings Feature**
  - Implement the SettingsView as a SwiftUI view
  - Create a UIHostingController to present it in the UIKit app
  - Integrate YOLO's existing settings (model selection, confidence threshold)
  - Add Tono's language settings (API key, language selection)
  - Test settings persistence

## Phase 5: Audio and Speech Integration

- [x] **Implement audio recording functionality**
  - Set up AVAudioRecorder for pronunciation practice
  - Implement proper audio session management
  - Add audio playback capabilities
  - Test recording and playback

- [x] **Implement text-to-speech**
  - Integrate SpeechManager for Chinese pronunciation
  - Ensure proper pronunciation of Chinese characters
  - Add controls for speech rate and volume
  - Test text-to-speech functionality

- [x] **Implement pronunciation feedback**
  - Integrate the PronunciationAPI
  - Implement visual feedback for pronunciation accuracy
  - Add gamification elements for pronunciation practice
  - Test pronunciation feedback

## Phase 6: Testing and Refinement

- [ ] **Test object detection performance**
  - Ensure YOLO detection still works efficiently
  - Test with various lighting conditions and scenarios
  - Optimize for performance if needed
  - Compare detection speed before and after integration

- [ ] **Test language learning features**
  - Verify all language learning features work correctly
  - Test pronunciation feedback accuracy
  - Ensure Core Data persistence works properly
  - Test with various Chinese characters and phrases

- [ ] **UI/UX testing**
  - Test on different iOS devices and screen sizes
  - Ensure proper layout in both orientations
  - Verify accessibility features
  - Test tab navigation and transitions

## Phase 7: Finalization

- [x] **Code cleanup and optimization**
  - Remove any redundant or unused code
  - Optimize performance bottlenecks
  - Ensure code follows consistent style guidelines
  - Add proper error handling

- [x] **Documentation**
  - Update README and documentation
  - Document the integration process and architecture
  - Add comments to code for future maintenance
  - Create user guide for new features

- [ ] **Prepare for distribution**
  - Update app icons and launch screen
  - Configure proper app permissions
  - Prepare for App Store submission if applicable
  - Test app signing and distribution

## Technical Considerations

### Architecture Decisions
- The YOLO app uses UIKit with Storyboards while Tono uses SwiftUI
- We'll use UIHostingController to embed SwiftUI views in UIKit
- Core Data integration will require careful planning for model versioning
- We'll keep the YOLO detection pipeline intact and extend it with translation capabilities

### Performance Considerations
- YOLO object detection is computationally intensive
- Adding language features should not significantly impact detection performance
- Consider background processing for non-critical tasks like pronunciation assessment
- Optimize Core Data queries for large collections

### Dependencies
- Ensure all required dependencies from both apps are properly integrated
- Resolve any dependency conflicts
- Consider using Swift Package Manager for managing dependencies
- Minimize third-party dependencies to reduce maintenance burden

### iOS Version Support
- YOLO requires iOS 17.0+ for trained models
- Ensure all features are compatible with iOS 17.0+
- Test on multiple iOS versions if possible
- Document minimum iOS version requirements
