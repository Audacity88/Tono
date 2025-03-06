### **Product Requirements Document (PRD) for AR Gamified Chinese Learning App**

---

## **1. Overview**

**Product Name:** TBD  
**Platform:** iOS  
**Primary Language:** Swift  
**Target Audience:** Beginner to intermediate Chinese learners with an iPhone (iOS 14+)  
**Core Concept:** An augmented reality (AR) app that helps users learn Chinese by exploring their surroundings and practicing vocabulary through gamified interactions. The app has two main modes: **Explore** and **Practice**. 

---

## **2. Objectives**

- Provide an immersive and engaging way to learn Chinese vocabulary through AR interactions.  
- Enhance pronunciation accuracy with real-time feedback using SpeechSuper.  
- Improve vocabulary retention using a Spaced Repetition System (SRS).  
- Ensure offline functionality for object recognition and pronunciation practice.  

---

## **3. Key Features**

### **3.1 Explore Mode**

**Description:**  
- Users explore the real world using their iPhone camera.  
- When an object is detected, a popup shows its Chinese name, pinyin, and pronunciation.  
- Users must repeat the pronunciation correctly to save the object to their collection.  
- Uses ARKit for AR capabilities and Core ML for object recognition.  

**Technologies:**  
- **AR:** ARKit  
- **Object Recognition:** Core ML  
- **Pronunciation Assessment:** SpeechSuper API, AudioKit for tone analysis  
- **Audio Playback:** AVFoundation  

**Key Interactions:**
- Scan and detect objects using the camera.  
- Display object name and pronunciation.  
- Record user pronunciation and provide feedback.  
- Save correctly pronounced objects to the user's collection.  

---

### **3.2 Practice Mode**

**Description:**  
- Users review objects in their collection through quizzes.  
- Quizzes assess recognition, pronunciation, and memory.  
- Points are awarded for correct answers, encouraging continued learning.  
- Utilizes an SRS algorithm to schedule reviews based on user performance.  

**Technologies:**  
- **Data Storage:** Core Data for storing objects and review schedules.  
- **SRS Algorithm:** Custom implementation in Swift (Leitner or SM-2).  
- **Audio Handling:** AVFoundation for playing audio during quizzes.  

**Key Interactions:**
- Display an object from the collection.  
- Quiz user on pronunciation and recognition.  
- Award points based on accuracy and response time.  
- Schedule next review based on performance.  

---

### **3.3 Pronunciation Feedback**

**Description:**  
- Assess user pronunciation in real-time using SpeechSuper API.  
- Analyze tones using AudioKit for pitch detection.  
- Provide corrective feedback if pronunciation or tone is incorrect.  

**Technologies:**  
- **Speech Recognition:** Speech framework, SpeechSuper API.  
- **Pitch Analysis:** AudioKit.  

---

### **3.4 Gamification Elements**

**Description:**  
- Points for correct answers in Practice mode.  
- Achievements for collecting objects or maintaining streaks.  
- Levels or badges based on the number of mastered words.  

**Technologies:**  
- **Data Storage:** Core Data.  
- **UI Elements:** SwiftUI for badges, progress bars, and point counters.  

---

### **3.5 User Interface**

**Technologies:**  
- **UI Framework:** SwiftUI.  
- **AR Integration:** UIViewRepresentable for embedding ARKit in SwiftUI.  
- **Offline Support:** Core ML for on-device processing.  

---

## **4. Technical Specifications**

### **4.1 Programming Language**
- **Swift**: Primary language due to modern syntax, performance, and native iOS support.  

### **4.2 AR and Object Recognition**
- **ARKit:** For AR capabilities like object placement and camera tracking.  
- **Core ML:** For offline object recognition.  
- **Pre-trained Models:** Custom models trained for commonly encountered objects.  

### **4.3 Audio Handling**
- **AVFoundation:** For playing and recording audio.  
- **Speech Framework:** For speech-to-text transcription.  
- **AudioKit:** For pitch detection and tone analysis.  

### **4.4 Data Storage**
- **Core Data:** For storing user data, including object collection, SRS schedules, and achievements.  

---

## **5. User Stories**

### **Explore Mode User Stories**

**1. Object Detection and Pronunciation**  
- **As a user,** I want to point my camera at objects and see their Chinese name and pronunciation so that I can learn vocabulary interactively.  

**2. Pronunciation Practice**  
- **As a user,** I want to repeat the pronunciation and get feedback so that I can improve my accent and tones.  

**3. Saving Objects**  
- **As a user,** I want to save objects to my collection by correctly pronouncing their names so that I can review them later.  

---

### **Practice Mode User Stories**

**1. Vocabulary Quiz**  
- **As a user,** I want to be quizzed on objects in my collection so that I can reinforce my memory of Chinese words.  

**2. Pronunciation Feedback in Practice**  
- **As a user,** I want to receive feedback on my pronunciation during quizzes so that I can improve my speaking skills.  

**3. SRS Scheduling**  
- **As a user,** I want my quizzes to be scheduled based on how well I remember words so that I can focus on words I find difficult.  

---

### **Gamification User Stories**

**1. Earning Points**  
- **As a user,** I want to earn points for correct answers so that I feel motivated to continue learning.  

**2. Achievements and Levels**  
- **As a user,** I want to unlock achievements and levels as I learn more words so that I stay motivated.  

---

## **6. Non-functional Requirements**

- **Performance:** Smooth object recognition and feedback within 1 second.  
- **Offline Support:** Must function without internet for object recognition and quizzes.  
- **Security:** Secure storage of user data using Core Data encryption.  

---

## **7. Technology Mapping Summary**

| **Feature**                            | **Technology**                              | **Purpose**                                        |
|----------------------------------------|----------------------------------------------|-----------------------------------------------------|
| AR Exploration                         | ARKit, Core ML                               | Real-time object detection and camera interaction   |
| Pronunciation Teaching                 | AVFoundation                                 | Play audio files for correct pronunciations         |
| User Speech Recording                  | AVFoundation                                 | Record user’s pronunciation attempts                |
| Pronunciation Assessment               | SpeechSuper API, AudioKit                    | Transcribe speech, assess tone                      |
| Data Storage                           | Core Data                                    | Store user collection and SRS data                  |
| Quiz Scheduling                        | Custom SRS (Swift)                           | Manage review intervals                             |
| User Interface                         | SwiftUI, UIViewRepresentable                 | Build UI, integrate ARKit views                     |

---

## **8. Risks and Mitigations**

| **Risk**                                      | **Impact** | **Mitigation Strategy**                                   |
|-----------------------------------------------|------------|----------------------------------------------------------|
| Object recognition accuracy                   | High       | Use pre-trained models and optimize Core ML integration   |
| Pronunciation assessment accuracy             | Medium     | Fine-tune AudioKit settings and use SpeechSuper API       |
| Offline storage limitations                   | Medium     | Optimize Core Data usage                                  |
| Performance on older devices                  | Medium     | Optimize ARKit and Core ML models for efficiency          |

---

## **9. Future Enhancements**

- Expand object recognition database with more items.  
- Add grammar-focused quizzes.  
- Introduce multiplayer challenges for practicing with friends.  
- Support additional languages.  

---

## **10. Conclusion**

This PRD outlines a comprehensive plan for an AR gamified Chinese learning app, leveraging Apple’s native frameworks to provide an immersive, offline-capable learning experience. The integration of ARKit, Core ML, and an SRS system ensures a balance between interactivity and effective vocabulary retention. By focusing on user-centric features and addressing potential risks, this document sets the stage for a successful development process.