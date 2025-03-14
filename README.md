# 🚀 Tono - AI-Powered Language Learning

Welcome to Tono, an innovative language learning app that combines advanced [YOLO11 object detection](https://github.com/ultralytics/ultralytics) with interactive Chinese language learning features. Transform your iOS device into an intelligent language learning tool that helps you learn Chinese vocabulary naturally through real-world object detection.

## 🌟 Features

- **Real-Time Object Detection & Translation**: Instantly detect objects and see their Chinese translations
- **Interactive Learning**: Tap on detected objects to:
  - View Chinese translations with pinyin
  - Hear native pronunciations
  - Practice your own pronunciation
  - Save items to your personal collection
- **Spaced Repetition**: Smart review system helps you remember vocabulary effectively
- **Multiple AI Models**: Choose from various YOLO11 models for optimal performance:
  - YOLO11n (fastest)
  - YOLO11s (balanced speed/accuracy)
  - YOLO11m (balanced)
  - YOLO11l (accurate)
  - YOLO11x (most accurate)
- **AR Integration**: Place 3D Chinese labels in your environment for immersive learning
- **Offline Support**: Core features work without internet connection

## 🛠 Getting Started

### Prerequisites

- **Xcode:** Latest version from the [Mac App Store](https://apps.apple.com/us/app/xcode/id497799835)
- **iOS Device:** iPhone or iPad running iOS 16.0 or later
- **Apple Developer Account:** Free account for testing (Sign up [here](https://developer.apple.com/))

### Installation

1. **Clone the Repository:**
   ```sh
   git clone git@github.com:Audacity88/Tono.git
   ```

2. **Open the Project:**
   - Open `Tono.xcodeproj` in Xcode
   - Select your development team in project settings

3. **Add YOLO11 Models:**
   Download and add the required YOLO11 models to the `Tono/Models` directory:
   - yolo11n.mlpackage (recommended default)
   - yolo11s.mlpackage
   - yolo11m.mlpackage
   - yolo11l.mlpackage
   - yolo11x.mlpackage

   You can create these models using the ultralytics package:
   ```python
   from ultralytics import YOLO
   
   # Export models to CoreML format
   for size in ("n", "s", "m", "l", "x"):
       model = YOLO(f"yolo11{size}.pt")
       model.export(format="coreml", int8=True, nms=True)
   ```

4. **Run the App:**
   - Connect your iOS device
   - Select it as the run target in Xcode
   - Build and run the project

## 💡 Usage Tips

1. **Getting Started:**
   - Allow camera access when prompted
   - Choose your preferred YOLO model (we recommend starting with YOLO11n)
   - Point your camera at objects to begin learning

2. **Learning Features:**
   - Tap detected objects to see translations and hear pronunciations
   - Use the AR mode to place persistent labels in your environment
   - Review saved items in the Collection tab
   - Practice pronunciation and take quizzes in the Practice tab

3. **Settings & Customization:**
   - Adjust detection confidence thresholds
   - Customize learning preferences
   - Configure pronunciation settings
   - Manage AR features


## 📄 License

This project is licensed under the AGPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## 🌐 Contact & Support

- **Issues:** Submit bug reports and feature requests via [GitHub Issues](https://github.com/Audacity88/Tono/issues)
- **Email:** For business inquiries, contact [support@tonoapp.com](mailto:support@tonoapp.com)

---

Built with ❤️ using [Ultralytics YOLO](https://github.com/ultralytics/ultralytics)