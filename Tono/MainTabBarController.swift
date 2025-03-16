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
        
        // 2. Collection Tab (SwiftUI)
        let collectionView = CollectionView()
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        let collectionHostingController = UIHostingController(rootView: collectionView)
        collectionHostingController.tabBarItem = UITabBarItem(
            title: "Collection",
            image: UIImage(systemName: "square.grid.2x2.fill"),
            tag: 1
        )
        
        // 3. Practice Tab (SwiftUI)
        let practiceView = PracticeView()
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        let practiceHostingController = UIHostingController(rootView: practiceView)
        practiceHostingController.tabBarItem = UITabBarItem(
            title: "Practice",
            image: UIImage(systemName: "book.fill"),
            tag: 2
        )
        
        // 4. Settings Tab (SwiftUI)
        let settingsView = SettingsView()
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        let settingsHostingController = UIHostingController(rootView: settingsView)
        settingsHostingController.tabBarItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: "gear"),
            tag: 3
        )
        
        // Set the view controllers
        viewControllers = [
            exploreNavController,
            collectionHostingController,
            practiceHostingController,
            settingsHostingController
        ]
    }
}

// MARK: - SwiftUI Views

// Placeholder for CollectionView
struct CollectionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaggedObject.timestamp, ascending: false)],
        animation: .default)
    private var items: FetchedResults<TaggedObject>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(items) { item in
                    VStack(alignment: .leading) {
                        Text(item.chinese ?? "Unknown")
                            .font(.headline)
                        Text(item.pinyin ?? "")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Text(item.english ?? "")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Collection")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting item: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// Placeholder for PracticeView
struct PracticeView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Practice Features Coming Soon")
                    .font(.headline)
                    .padding()
                
                List {
                    NavigationLink(destination: Text("Flashcards Coming Soon")) {
                        HStack {
                            Image(systemName: "rectangle.fill.on.rectangle.fill")
                                .foregroundColor(.blue)
                            Text("Flashcards")
                        }
                    }
                    
                    NavigationLink(destination: Text("Quiz Coming Soon")) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Quiz")
                        }
                    }
                    
                    NavigationLink(destination: Text("Pronunciation Practice Coming Soon")) {
                        HStack {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.red)
                            Text("Pronunciation Practice")
                        }
                    }
                }
            }
            .navigationTitle("Practice")
        }
    }
}

// Placeholder for SettingsView
struct SettingsView: View {
    @State private var selectedModelIndex = 2 // Default to yolo11m
    @State private var confidenceThreshold = 0.25
    @State private var iouThreshold = 0.45
    @State private var apiKey = ""
    
    private let models = ["yolo11n", "yolo11s", "yolo11m", "yolo11l", "yolo11x"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("YOLO Model")) {
                    Picker("Model", selection: $selectedModelIndex) {
                        ForEach(0..<models.count, id: \.self) { index in
                            Text(models[index]).tag(index)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Detection Settings")) {
                    VStack {
                        HStack {
                            Text("Confidence Threshold")
                            Spacer()
                            Text("\(Int(confidenceThreshold * 100))%")
                        }
                        Slider(value: $confidenceThreshold, in: 0.1...0.9, step: 0.05)
                    }
                    
                    VStack {
                        HStack {
                            Text("IoU Threshold")
                            Spacer()
                            Text("\(Int(iouThreshold * 100))%")
                        }
                        Slider(value: $iouThreshold, in: 0.1...0.9, step: 0.05)
                    }
                }
                
                Section(header: Text("Language Settings")) {
                    TextField("Pronunciation API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button("Save API Key") {
                        UserDefaults.standard.set(apiKey, forKey: "FluentAPIKey")
                    }
                    .disabled(apiKey.isEmpty)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                    }
                    
                    HStack {
                        Text("YOLO Model")
                        Spacer()
                        Text("YOLO11")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
} 