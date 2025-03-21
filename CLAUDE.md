# CLAUDE.md - Development Guidelines

## Build Commands
- Open `Tono.xcodeproj` in Xcode
- Select development team in project settings
- Build and run on iOS device (iOS 16.0+ required)

## Testing
- Tests use Apple's built-in XCTest framework
- Run tests in Xcode: Product > Test (⌘U)
- Run single test: Click play button next to test function

## Style Guidelines
- **Naming**: PascalCase for types, camelCase for variables/functions
- **Imports**: Foundation first, UIKit/SwiftUI next, domain-specific last
- **Documentation**: Use triple-slash (`///`) comments for public APIs
- **Organization**: Use MARK comments (`// MARK: - Section`)
- **Error Handling**: Use optional chaining, try/catch, or completion handlers with Result
- **Extensions**: Used to organize functionality by feature

## Project Structure
- Models/ - Data models and persistence
- Views/ - SwiftUI components and view controllers
- Utilities/ - Helper classes and managers

## Special Notes
- Do not edit plist or pbxproj files directly, provide Xcode instructions instead