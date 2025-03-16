import SwiftUI
import CoreData

struct ContentView: View {
    @State private var selectedTab = 0
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ARExploreView()
                .tabItem {
                    Label("Explore", systemImage: "camera.viewfinder")
                }
                .tag(0)
            
            CollectionView()
                .environment(\.managedObjectContext, viewContext)
                .tabItem {
                    Label("Collection", systemImage: "square.grid.2x2")
                }
                .tag(1)
            
            PracticeView()
                .environment(\.managedObjectContext, viewContext)
                .tabItem {
                    Label("Practice", systemImage: "book")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 