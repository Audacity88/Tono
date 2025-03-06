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
            // Explore Mode (AR View)
            ARExploreView()
                .tabItem {
                    Label("Explore", systemImage: "camera.viewfinder")
                }
                .tag(0)
            
            // Practice Mode (Coming soon)
            PracticeView()
                .tabItem {
                    Label("Practice", systemImage: "book.fill")
                }
                .tag(1)
            
            // Collection (Items saved by the user)
            CollectionView(viewContext: viewContext)
                .tabItem {
                    Label("Collection", systemImage: "square.grid.2x2.fill")
                }
                .tag(2)
            
            // Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
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

// Placeholder for Collection View
struct CollectionView: View {
    var viewContext: NSManagedObjectContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp!, formatter: itemFormatter)")
                    } label: {
                        Text(item.timestamp!, formatter: itemFormatter)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("My Collection")
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
                print("Unresolved error \(nsError), \(nsError.userInfo)")
            }
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

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
