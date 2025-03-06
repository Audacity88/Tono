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
    
    var body: some View {
        TabView {
            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "camera.viewfinder")
                }
            
            PracticeView()
                .tabItem {
                    Label("Practice", systemImage: "book.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .accentColor(.orange)
    }
}

struct ExploreView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Explore Mode")
                    .font(.largeTitle)
                    .padding()
                
                Text("Point your camera at objects to learn their Chinese names")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
                
                Button(action: {
                    // This will be implemented later to start AR session
                }) {
                    Text("Start Scanning")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                }
                .padding(.bottom, 50)
            }
            .navigationTitle("Explore")
        }
    }
}

struct PracticeView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Practice Mode")
                    .font(.largeTitle)
                    .padding()
                
                Text("Review your collected words and practice pronunciation")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
                
                Text("No words collected yet")
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .navigationTitle("Practice")
        }
    }
}

struct ProfileView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Your Profile")
                    .font(.largeTitle)
                    .padding()
                
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Level:")
                            .font(.headline)
                        Text("Beginner")
                    }
                    
                    HStack {
                        Text("Words Collected:")
                            .font(.headline)
                        Text("0")
                    }
                    
                    HStack {
                        Text("Points:")
                            .font(.headline)
                        Text("0")
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
