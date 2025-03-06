// ARExploreView.swift
// Tono
//
// Created as part of the AR Gamified Chinese Learning App

import SwiftUI

struct ARExploreView: View {
    @State private var detectedObject: (english: String, chinese: String, pinyin: String)?
    @State private var showPopup = false
    
    var body: some View {
        ZStack {
            // AR View
            ARViewWrapper(onObjectDetected: { english, chinese, pinyin in
                detectedObject = (english, chinese, pinyin)
                showPopup = true
            })
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
            
            // Instructions overlay
            VStack {
                HStack {
                    Spacer()
                    
                    Text("Tap on objects to identify them")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding(.top, 10)
                        .padding(.trailing, 10)
                }
                
                Spacer()
            }
        }
        .statusBar(hidden: true)
    }
}

struct ARExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ARExploreView()
    }
} 