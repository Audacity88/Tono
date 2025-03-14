<a href="https://www.ultralytics.com/" target="_blank"><img src="https://raw.githubusercontent.com/ultralytics/assets/main/logo/Ultralytics_Logotype_Original.svg" width="320" alt="Ultralytics logo"></a>

# 🚀 Tono - AI-Powered Language Learning

[![Ultralytics Actions](https://github.com/ultralytics/yolo-ios-app/actions/workflows/format.yml/badge.svg)](https://github.com/ultralytics/yolo-ios-app/actions/workflows/format.yml) <a href="https://discord.com/invite/ultralytics"><img alt="Discord" src="https://img.shields.io/discord/1089800235347353640?logo=discord&logoColor=white&label=Discord&color=blue"></a> <a href="https://community.ultralytics.com/"><img alt="Ultralytics Forums" src="https://img.shields.io/discourse/users?server=https%3A%2F%2Fcommunity.ultralytics.com&logo=discourse&label=Forums&color=blue"></a> <a href="https://reddit.com/r/ultralytics"><img alt="Ultralytics Reddit" src="https://img.shields.io/reddit/subreddit-subscribers/ultralytics?style=flat&logo=reddit&logoColor=white&label=Reddit&color=blue"></a>

Welcome to Tono, an innovative language learning app that combines Ultralytics' advanced [YOLO11 object detection models](https://github.com/ultralytics/ultralytics) with interactive Chinese language learning features. Transform your iOS device into an intelligent language learning tool that helps you learn Chinese vocabulary naturally through real-world object detection.

<div align="center">
  <a href="https://apps.apple.com/us/app/idetection/id1452689527" target="_blank"><img width="90%" src="https://github.com/ultralytics/ultralytics/assets/26833433/fd3c8a92-fec0-4253-b4ac-ee94f5ced3fb" alt="Ultralytics YOLO iOS App previews"></a>
  <br>
  <a href="https://github.com/ultralytics"><img src="https://github.com/ultralytics/assets/raw/main/social/logo-social-github.png" width="3%" alt="Ultralytics GitHub"></a>
  <img src="https://github.com/ultralytics/assets/raw/main/social/logo-transparent.png" width="3%" alt="space">
  <a href="https://www.linkedin.com/company/ultralytics/"><img src="https://github.com/ultralytics/assets/raw/main/social/logo-social-linkedin.png" width="3%" alt="Ultralytics LinkedIn"></a>
  <img src="https://github.com/ultralytics/assets/raw/main/social/logo-transparent.png" width="3%" alt="space">
  <a href="https://twitter.com/ultralytics"><img src="https://github.com/ultralytics/assets/raw/main/social/logo-social-twitter.png" width="3%" alt="Ultralytics Twitter"></a>
  <img src="https://github.com/ultralytics/assets/raw/main/social/logo-transparent.png" width="3%" alt="space">
  <a href="https://youtube.com/ultralytics?sub_confirmation=1"><img src="https://github.com/ultralytics/assets/raw/main/social/logo-social-youtube.png" width="3%" alt="Ultralytics YouTube"></a>
  <img src="https://github.com/ultralytics/assets/raw/main/social/logo-transparent.png" width="3%" alt="space">
  <a href="https://www.tiktok.com/@ultralytics"><img src="https://github.com/ultralytics/assets/raw/main/social/logo-social-tiktok.png" width="3%" alt="Ultralytics TikTok"></a>
  <img src="https://github.com/ultralytics/assets/raw/main/social/logo-transparent.png" width="3%" alt="space">
  <a href="https://ultralytics.com/bilibili"><img src="https://github.com/ultralytics/assets/raw/main/social/logo-social-bilibili.png" width="3%" alt="Ultralytics BiliBili"></a>
  <img src="https://github.com/ultralytics/assets/raw/main/social/logo-transparent.png" width="3%" alt="space">
  <a href="https://discord.com/invite/ultralytics"><img src="https://github.com/ultralytics/assets/raw/main/social/logo-social-discord.png" width="3%" alt="Ultralytics Discord"></a>
  <br>
  <br>
  <a href="https://apps.apple.com/us/app/idetection/id1452689527" style="text-decoration:none;">
    <img src="https://raw.githubusercontent.com/ultralytics/assets/main/app/app-store.svg" width="15%" alt="Apple App store"></a>
</div>

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

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting pull requests.

## 📄 License

This project is licensed under the AGPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## 🌐 Contact & Support

- **Issues:** Submit bug reports and feature requests via [GitHub Issues](https://github.com/Audacity88/Tono/issues)
- **Email:** For business inquiries, contact [support@tonoapp.com](mailto:support@tonoapp.com)

---

Built with ❤️ using [Ultralytics YOLO](https://github.com/ultralytics/ultralytics)

## 💡 Contribute

We warmly welcome your contributions to Ultralytics' open-source projects! Your support and contributions significantly impact. Get involved by reviewing our [Contributing Guide](https://docs.ultralytics.com/help/contributing/), and share your feedback through our [Survey](https://www.ultralytics.com/survey?utm_source=github&utm_medium=social&utm_campaign=Survey). A massive thank you 🙏 to everyone who contributes!

<a href="https://github.com/ultralytics/yolov5/graphs/contributors">
<img width="100%" src="https://github.com/ultralytics/assets/raw/main/im/image-contributors.png" alt="Ultralytics open-source contributors"></a>

## 📄 License

Ultralytics offers two licensing options:

- **AGPL-3.0 License**: An [OSI-approved](https://opensource.org/license) open-source license, perfect for academics, researchers, and enthusiasts. It encourages sharing knowledge and collaboration. See the [LICENSE](https://github.com/ultralytics/ultralytics/blob/main/LICENSE) file for details.

- **Enterprise License**: Designed for commercial use, this license permits integrating Ultralytics software into proprietary products and services. For commercial use, please contact us through [Ultralytics Licensing](https://www.ultralytics.com/license).

## 🤝 Contact

- Submit Ultralytics bug reports and feature requests via [GitHub Issues](https://github.com/ultralytics/yolo-ios-app/issues).
- Join our [Discord](https://discord.com/invite/ultralytics) for assistance, questions, and discussions with the community and team!

<br>
<div align="center">
  <a href="https://github.com/ultralytics"><img src="https://github.com/ultralytics/assets/raw/main/social/logo-social-github.png" width="3%" alt="Ultralytics GitHub"></a>
  <img src="https://github.com/ultralytics/assets/raw/main/social/logo-transparent.png" width="3%" alt="space">
  <a href="https://www.linkedin.com/company/ultralytics/"><img src="https://github.com/ultralytics/assets/raw/main/social/logo-social-linkedin.png" width="3%" alt="Ultralytics LinkedIn"></a>
  <img src="https://github.com/ultralytics/assets/raw/main/social/logo-transparent.png" width="3%" alt="space">
  <a href="https://twitter.com/ultralytics"><img src="https://github.com/ultralytics/assets/raw/main/social/logo-social-twitter.png" width="3%" alt="Ultralytics Twitter"></a>
  <img src="https://github.com/ultralytics/assets/raw/main/social/logo-transparent.png" width="3%" alt="space">
  <a href="https://youtube.com/ultralytics?sub_confirmation=1"><img src="https://github.com/ultralytics/assets/raw/main/social/logo-social-youtube.png" width="3%" alt="Ultralytics YouTube"></a>
  <img src="https://github.com/ultralytics/assets/raw/main/social/logo-transparent.png" width="3%" alt="space">
  <a href="https://www.tiktok.com/@ultralytics"><img src="https://github.com/ultralytics/assets/raw/main/social/logo-social-tiktok.png" width="3%" alt="Ultralytics TikTok"></a>
  <img src="https://github.com/ultralytics/assets/raw/main/social/logo-transparent.png" width="3%" alt="space">
  <a href="https://ultralytics.com/bilibili"><img src="https://github.com/ultralytics/assets/raw/main/social/logo-social-bilibili.png" width="3%" alt="Ultralytics BiliBili"></a>
  <img src="https://github.com/ultralytics/assets/raw/main/social/logo-transparent.png" width="3%" alt="space">
  <a href="https://discord.com/invite/ultralytics"><img src="https://github.com/ultralytics/assets/raw/main/social/logo-social-discord.png" width="3%" alt="Ultralytics Discord"></a>
</div>

## 🌏 Tono Integration: Language Learning with YOLO

This version of the Ultralytics YOLO iOS App includes integration with Tono, a language learning system that enhances object detection with Chinese translations and learning features.

### New Features

- **Object Translation**: Detected objects are automatically translated to Chinese with pinyin pronunciation
- **Interactive Learning**: Tap on detected objects to see translations, hear pronunciations, and save to your collection
- **Collection Management**: Save detected objects to review and practice later
- **Practice Tools**: Use flashcards, quizzes, and pronunciation practice to improve your Chinese vocabulary
- **Customizable Settings**: Configure both YOLO detection and language learning settings

### How to Use

1. **Enable Tab Bar Interface**: Go to Settings app > YOLO > Interface Settings > Enable "Use Tab Bar Interface"
2. **Explore Tab**: Use the camera to detect objects and see their Chinese translations
3. **Collection Tab**: View and manage your saved objects
4. **Practice Tab**: Use various learning tools to practice your vocabulary
5. **Settings Tab**: Configure detection and language learning settings

### Technical Details

The integration combines the powerful object detection capabilities of YOLO with language learning features:

- UIKit and SwiftUI integration using UIHostingController
- Core Data for persistent storage of learned vocabulary
- Text-to-speech for Chinese pronunciation
- Pronunciation assessment for speaking practice
