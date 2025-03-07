// ARExploreView.swift
// Tono
//
// Created as part of the AR Gamified Chinese Learning App

import SwiftUI

struct ARExploreView: View {
    @State private var detectedObject: (english: String, chinese: String, pinyin: String)?
    @State private var showPopup = false
    
    // This property will be set by the parent view (ContentView)
    var isActive: Bool = true
    
    var body: some View {
        ZStack {
            // AR View
            ARViewWrapper(
                onObjectDetected: { english, chinese, pinyin in
                    detectedObject = (english, chinese, pinyin)
                    showPopup = true
                },
                isActive: isActive
            )
            .edgesIgnoringSafeArea(.all)
            
            // Popup for detected object
            if showPopup, let object = detectedObject {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Text(object.chinese)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.red)
                        
                        Text(object.pinyin)
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        
                        Text(object.english)
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                        
                        Button(action: {
                            // Play pronunciation (would be implemented in a full app)
                            showPopup = false
                        }) {
                            Text("Close")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(15)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            
            // UI Controls
            VStack {
                // Top controls
                HStack {
                    // Reset button
                    Button(action: {
                        // Post notification directly to clear labels
                        NotificationCenter.default.post(name: NSNotification.Name("ClearARLabels"), object: nil)
                    }) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.blue.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(radius: 3)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1.5)
                                    .opacity(0.7)
                            )
                    }
                    .padding(.leading, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Instructions
                    Text("Tap on objects to identify them")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding(.top, 10)
                        .padding(.trailing, 20)
                }
                
                Spacer()
            }
        }
    }
}

struct ARExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ARExploreView(isActive: true)
    }
} 