### **Checklist for Building the AR Gamified Chinese Learning App**

---

## **1. Project Setup**

- [x] Install and configure **Xcode** (latest version).  
- [x] Create a new **iOS project** in Xcode using **Swift** and **SwiftUI**.  
- [x] Set up a **Git repository** for version control (GitHub or GitLab).  
- [x] Define **app bundle ID** and configure **App Store Connect** account.  
- [x] Integrate **Swift Package Manager** for dependency management.  

---

## **2. Core Technologies Setup**

### **2.1 ARKit and Core ML Integration**

- [x] Enable **ARKit** in the Xcode project settings.  
- [x] Import **ARKit** and **Core ML** frameworks.  
- [x] Download or create a pre-trained **Core ML model** for object recognition.  
- [x] Convert the model to **Core ML format** if necessary using Core ML Tools.  
- [x] Implement a **UIViewRepresentable** wrapper for ARKit in SwiftUI.  
- [x] Build a simple AR scene to test object recognition capabilities.  

---

### **2.2 Audio and Pronunciation Setup**

- [x] Enable **Microphone and Speech Recognition** capabilities in Xcode.  
- [x] Import **AVFoundation**, **AudioKit**, and **Speech** frameworks.  
- [ ] Install and configure **SpeechSuper API** for pronunciation assessment.  
- [x] Develop a prototype for **audio playback** using AVFoundation.  
- [x] Create a basic **speech recording and transcription** function using the Speech framework.  

---

### **2.3 Data Storage Configuration**

- [x] Add **Core Data** to the project for local storage.  
- [ ] Define data models in Core Data for:
  - Objects (name, image, pronunciation, SRS data).  
  - SRS schedule (last review date, interval, performance).  
  - User achievements and progress.  
- [ ] Implement a simple **CRUD** (Create, Read, Update, Delete) interface for testing.  

---

### **3. Building Core Features**

---

### **3.1 Explore Mode**

- [x] Create a **SwiftUI view** for the camera interface using ARKit.  
- [x] Integrate **Core ML** for real-time object recognition.  
- [x] Display **popups with Chinese names, pinyin, and pronunciation**.  
- [x] Implement **speech recording** and send audio to SpeechSuper API for assessment.  
- [x] Provide **feedback on pronunciation** (correct or retry).  
- [ ] Save correctly pronounced objects to Core Data.  
- [ ] Test for **accuracy and performance** on multiple devices.  

---

### **3.2 Practice Mode**

- [ ] Design a **SwiftUI view** for quizzes (object images and multiple-choice questions).  
- [ ] Retrieve objects from **Core Data** based on SRS schedule.  
- [ ] Develop a **custom SRS algorithm** in Swift (Leitner or SM-2).  
- [ ] Implement a **point system** for correct answers.  
- [ ] Provide **pronunciation feedback** using SpeechSuper and AudioKit.  
- [ ] Test **SRS functionality** for appropriate intervals and difficulty.  

---

### **3.3 Pronunciation Feedback**

- [ ] Extract **pitch and tone** using AudioKit.  
- [ ] Compare user pronunciation to **reference pitch** for tone accuracy.  
- [ ] Display **visual feedback** (green for correct, red for incorrect).  
- [ ] Store **performance data** in Core Data for future quizzes.  

---

### **4. Gamification Elements**

- [ ] Create a **SwiftUI dashboard** for points, levels, and achievements.  
- [ ] Define **achievement criteria** (e.g., 10 correct pronunciations in a row).  
- [ ] Store and update **progress data** in Core Data.  
- [ ] Implement **notifications or popups** for new levels or badges.  

---

### **5. User Interface Design**

- [ ] Create **SwiftUI components** for:
  - Explore mode (camera, popups).  
  - Practice mode (quizzes, feedback).  
  - Dashboard (points, achievements).  
- [ ] Design a **consistent UI theme** with colors and icons.  
- [ ] Ensure **responsive design** for different screen sizes (iPhone SE to iPhone 14 Pro Max).  
- [ ] Implement **UIViewRepresentable** to integrate ARKit scenes.  
- [ ] Test for **usability and accessibility** (VoiceOver and contrast ratios).  

---

### **6. Performance Optimization**

- [ ] Optimize **Core ML models** for mobile performance (quantization, pruning).  
- [ ] Test **ARKit frame rates** and adjust for lag or delay.  
- [ ] Minimize **network requests** for SpeechSuper API using caching.  
- [ ] Implement **background tasks** for data saving in Core Data.  
- [ ] Monitor memory usage and optimize as needed.  

---

### **7. Offline Functionality**

- [ ] Ensure **Core ML and AudioKit** work offline.  
- [ ] Cache pronunciation files locally using **AVFoundation**.  
- [ ] Validate **Core Data sync** without internet.  
- [ ] Test **full app functionality** in airplane mode.  

---

### **8. Permissions and Security**

- [ ] Request permissions for:
  - Camera access (ARKit).  
  - Microphone access (Speech).  
  - Speech recognition (SpeechSuper API).  
- [ ] Encrypt **Core Data** storage for user data security.  
- [ ] Implement a **privacy policy** in the app settings.  

---

### **9. Testing and QA**

- [ ] Write **unit tests** for:
  - Object recognition accuracy.  
  - Pronunciation feedback logic.  
  - SRS scheduling and data retrieval.  
- [ ] Conduct **integration testing** for:
  - ARKit and Core ML.  
  - Audio recording and SpeechSuper API.  
- [ ] Perform **UI testing** for:
  - Navigation between explore and practice modes.  
  - Responsiveness on different screen sizes.  
- [ ] Gather **beta tester feedback** via TestFlight.  
- [ ] Fix bugs and optimize based on tester input.  

---

### **10. App Store Preparation**

- [ ] Create **App Store screenshots** and promo video.  
- [ ] Write **app description** focusing on AR and gamification.  
- [ ] Ensure compliance with **App Store guidelines**.  
- [ ] Submit for **App Store review** and address feedback.  

---

### **11. Future Enhancements**

- [ ] Expand object recognition to **more categories** (e.g., food, places).  
- [ ] Implement **grammar quizzes** for advanced users.  
- [ ] Introduce **multiplayer challenges** for practice mode.  
- [ ] Develop **in-app purchases** for additional features or objects.  

---

### **Summary Checklist**

**Total Steps:** 73  
- [ ] **Project Setup:** 5 steps  
- [ ] **Core Technologies:** 16 steps  
- [ ] **Core Features:** 20 steps  
- [ ] **User Interface:** 5 steps  
- [ ] **Performance and Offline:** 8 steps  
- [ ] **Permissions and Security:** 5 steps  
- [ ] **Testing and QA:** 10 steps  
- [ ] **App Store:** 4 steps  

---

This checklist provides a comprehensive, step-by-step guide for developing the AR gamified Chinese learning app, ensuring all aspects—from core features to testing and deployment—are covered.