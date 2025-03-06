// ARViewWrapper.swift
// Tono
//
// Created as part of the AR Gamified Chinese Learning App

import SwiftUI
import UIKit
import CoreData

struct ARViewWrapper: UIViewControllerRepresentable {
    // Callback for when an object is detected
    var onObjectDetected: ((String, String, String) -> Void)?
    
    // Core Data managed object context
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    func makeUIViewController(context: Context) -> ARViewController {
        let viewController = ARViewController()
        viewController.onObjectDetected = onObjectDetected
        viewController.managedObjectContext = managedObjectContext
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        // Update the view controller if needed
        uiViewController.managedObjectContext = managedObjectContext
    }
}

// Preview provider for SwiftUI previews
struct ARViewWrapper_Previews: PreviewProvider {
    static var previews: some View {
        ARViewWrapper()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 