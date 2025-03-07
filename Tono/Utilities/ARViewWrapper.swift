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
    
    // Flag to control AR session state
    var isActive: Bool
    
    // Core Data managed object context
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    // Create a coordinator to handle communication
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIViewController(context: Context) -> ARViewController {
        let viewController = ARViewController()
        viewController.onObjectDetected = onObjectDetected
        viewController.managedObjectContext = managedObjectContext
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        // Update the view controller if needed
        uiViewController.managedObjectContext = managedObjectContext
        
        // Pause or resume AR session based on isActive flag
        if isActive {
            uiViewController.resumeARSession()
        } else {
            uiViewController.pauseARSession()
        }
    }
    
    // Coordinator class to handle communication between SwiftUI and UIKit
    class Coordinator: NSObject {
        // You can add properties and methods here if needed
    }
}

// Preview provider for SwiftUI previews
struct ARViewWrapper_Previews: PreviewProvider {
    static var previews: some View {
        ARViewWrapper(isActive: true)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 