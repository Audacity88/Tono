import SwiftUI
import UIKit
import AVFoundation
import Vision
import CoreML

struct YOLOViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ViewController {
        // Load the storyboard
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        // Get the initial ViewController from storyboard
        guard let viewController = storyboard.instantiateInitialViewController() as? ViewController else {
            fatalError("Failed to load ViewController from storyboard")
        }
        
        // Adjust the view controller to work with tab bar
        viewController.modalPresentationStyle = .fullScreen
        viewController.edgesForExtendedLayout = []  // Don't extend under bars
        
        // Add a method to adjust constraints when view appears
        viewController.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 49, right: 0) // Standard tab bar height
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        // Update the view controller if needed
    }
} 