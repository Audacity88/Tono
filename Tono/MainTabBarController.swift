//
//  MainTabBarController.swift
//  YOLO
//
//  Created as part of the Tono integration
//

import UIKit
import SwiftUI
import CoreData

class MainTabBarController: UITabBarController {
    
    // Reference to the Core Data persistence controller
    private let persistenceController = PersistenceController.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the tab bar appearance
        setupAppearance()
        
        // Set up the view controllers for each tab
        setupViewControllers()
    }
    
    private func setupAppearance() {
        // Set the tab bar appearance
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .systemBackground
            
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
        
        // Set the tab bar tint color
        tabBar.tintColor = .systemBlue
    }
    
    private func setupViewControllers() {
        // 1. Explore Tab (YOLO Detection)
        let exploreVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ViewController") as! ViewController
        let exploreNavController = UINavigationController(rootViewController: exploreVC)
        exploreNavController.tabBarItem = UITabBarItem(
            title: "Explore",
            image: UIImage(systemName: "camera.viewfinder"),
            tag: 0
        )
        
        // 2. Collection Tab (Using UIKit CollectionViewController)
        let collectionVC = CollectionViewController()
        collectionVC.context = persistenceController.container.viewContext
        let collectionNavController = UINavigationController(rootViewController: collectionVC)
        collectionNavController.tabBarItem = UITabBarItem(
            title: "Collection",
            image: UIImage(systemName: "square.grid.2x2.fill"),
            tag: 1
        )
        
        // 3. Settings Tab (Using UIKit)
        let settingsVC = UIViewController()
        settingsVC.title = "Settings"
        settingsVC.view.backgroundColor = .systemBackground
        settingsVC.tabBarItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: "gear"),
            tag: 2
        )
        
        // Set the view controllers
        viewControllers = [
            exploreNavController,
            collectionNavController,
            settingsVC
        ]
    }
}

// MainTabBarController uses UIKit controllers for navigation