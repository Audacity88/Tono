import SwiftUI
import AVFoundation
import UIKit

struct ARExploreView: View {
    @State private var isShowingSettings = false
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                YOLOViewControllerRepresentable()
                    .ignoresSafeArea(.all, edges: .top) // Only ignore top safe area
                
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            isShowingSettings = true
                        }) {
                            Image(systemName: "gear")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding(.top, geometry.safeAreaInsets.top)
                        .padding(.trailing)
                    }
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }
} 