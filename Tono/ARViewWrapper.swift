// ARViewWrapper.swift
// Tono
//
// Created as part of the AR Gamified Chinese Learning App

import SwiftUI
import UIKit

struct ARViewWrapper: UIViewControllerRepresentable {
    // Callback for when an object is detected
    var onObjectDetected: ((String, String, String) -> Void)?
    
    func makeUIViewController(context: Context) -> ARViewController {
        let viewController = ARViewController()
        viewController.onObjectDetected = onObjectDetected
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        // Update the view controller if needed
    }
}

// Preview provider for SwiftUI previews
struct ARViewWrapper_Previews: PreviewProvider {
    static var previews: some View {
        ARViewWrapper()
    }
} 