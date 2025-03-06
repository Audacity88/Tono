# Tono - AR Gamified Chinese Learning App

An augmented reality (AR) app that helps users learn Chinese by exploring their surroundings and practicing vocabulary through gamified interactions.

## Overview

Tono is an iOS application designed to make learning Chinese vocabulary engaging and effective through:

- **AR Exploration**: Scan real-world objects to learn their Chinese names
- **Pronunciation Practice**: Get real-time feedback on your pronunciation
- **Gamified Learning**: Earn points and achievements as you learn
- **Spaced Repetition**: Review words at optimal intervals for better retention

## Features

### Explore Mode
- Point your camera at objects to see their Chinese names and pronunciation
- Practice pronouncing words correctly to add them to your collection
- Uses ARKit and Core ML for object recognition

### Practice Mode
- Review collected words through interactive quizzes
- Receive feedback on pronunciation accuracy
- Spaced repetition system schedules reviews based on your performance

## Technical Stack

- **Platform**: iOS 14+
- **Language**: Swift
- **UI Framework**: SwiftUI
- **AR**: ARKit
- **Object Recognition**: Core ML (YOLOv8, Inceptionv3, MobileNet)
- **Pronunciation Assessment**: SpeechSuper API, AudioKit
- **Data Storage**: Core Data

## Getting Started

### Prerequisites

- Xcode (latest version)
- iOS device with ARKit support (iPhone 6s or later, running iOS 14+)

### Installation

1. Clone this repository
   ```
   git clone https://github.com/yourusername/Tono.git
   ```
2. Open the project in Xcode
   ```
   open Tono.xcodeproj
   ```
3. Build and run the project on your iOS device

## Development Status

This project is currently in the initial development phase. See the [checklist](docs/Checklist.md) for progress updates.

## Acknowledgments

This project is based on the [CoreML-in-ARKit](https://github.com/hanleyweng/CoreML-in-ARKit) project by Hanley Weng, which provides a foundation for integrating Core ML with ARKit for object detection.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

*Note: This project is a work in progress.* 