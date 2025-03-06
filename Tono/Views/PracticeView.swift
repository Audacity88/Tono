//
//  PracticeView.swift
//  Tono
//
//  Created by Daniel Gilles on 3/6/25.
//

import SwiftUI

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

#Preview {
    PracticeView()
} 