import SwiftUI
import CoreData
import AVFoundation

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Explore Mode (AR)
            ARExploreView(isActive: selectedTab == 0)
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text("Explore")
                }
                .tag(0)
            
            // Collection (Items saved by the user)
            CollectionView()
                .tabItem {
                    Label("Collection", systemImage: "square.grid.2x2.fill")
                }
                .tag(1)
            
            // Practice Mode
            PracticeView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Practice")
                }
                .tag(2)
            
            // Settings
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .onChange(of: selectedTab) { newTab in
            // Log tab changes for debugging
            print("Tab changed to: \(newTab)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 