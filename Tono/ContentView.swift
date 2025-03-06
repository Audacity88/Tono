//
//  ContentView.swift
//  Tono
//
//  Created by Daniel Gilles on 3/6/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Explore Mode (AR)
            ARExploreView()
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text("Explore")
                }
                .tag(0)
            
            // Practice Mode (placeholder)
            PracticeView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Practice")
                }
                .tag(1)
            
            // Collection (Items saved by the user)
            CollectionView()
                .tabItem {
                    Label("Collection", systemImage: "square.grid.2x2.fill")
                }
                .tag(2)
            
            // Settings (placeholder)
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
    }
}

// Placeholder for Practice View
struct PracticeView: View {
    var body: some View {
        VStack {
            Text("Practice Mode")
                .font(.largeTitle)
                .padding()
            
            Text("Coming Soon")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// Placeholder for Settings View
struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("App Settings")) {
                    Toggle("Enable Notifications", isOn: .constant(true))
                    Toggle("Dark Mode", isOn: .constant(false))
                }
                
                Section(header: Text("Account")) {
                    Text("Sign In")
                    Text("Privacy Policy")
                    Text("Terms of Service")
                }
                
                Section(header: Text("About")) {
                    Text("Version 1.0.0")
                    Text("© 2025 Gauntlet AI")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
