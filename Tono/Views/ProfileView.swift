//
//  ProfileView.swift
//  Tono
//
//  Created by Daniel Gilles on 3/6/25.
//

import SwiftUI

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
    ProfileView()
} 