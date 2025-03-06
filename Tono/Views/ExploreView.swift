//
//  ExploreView.swift
//  Tono
//
//  Created by Daniel Gilles on 3/6/25.
//

import SwiftUI

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

#Preview {
    ExploreView()
} 