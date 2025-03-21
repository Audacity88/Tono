import SwiftUI
import CoreData

struct SettingsView: View {
    @State private var selectedModelIndex = 2 // Default to yolo11m
    @State private var confidenceThreshold = 0.25
    @State private var iouThreshold = 0.45
    @State private var apiKey = ""
    
    private let models = ["yolo11n", "yolo11s", "yolo11m", "yolo11l", "yolo11x"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("YOLO Model")) {
                    Picker("Model", selection: $selectedModelIndex) {
                        ForEach(0..<models.count, id: \.self) { index in
                            Text(models[index]).tag(index)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Detection Settings")) {
                    VStack {
                        HStack {
                            Text("Confidence Threshold")
                            Spacer()
                            Text("\(Int(confidenceThreshold * 100))%")
                        }
                        Slider(value: $confidenceThreshold, in: 0.1...0.9, step: 0.05)
                    }
                    
                    VStack {
                        HStack {
                            Text("IoU Threshold")
                            Spacer()
                            Text("\(Int(iouThreshold * 100))%")
                        }
                        Slider(value: $iouThreshold, in: 0.1...0.9, step: 0.05)
                    }
                }
                
                Section(header: Text("Language Settings")) {
                    TextField("Pronunciation API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button("Save API Key") {
                        UserDefaults.standard.set(apiKey, forKey: "FluentAPIKey")
                    }
                    .disabled(apiKey.isEmpty)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                    }
                    
                    HStack {
                        Text("YOLO Model")
                        Spacer()
                        Text("YOLO11")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                // Load API key from UserDefaults if available
                if let savedKey = UserDefaults.standard.string(forKey: "FluentAPIKey") {
                    apiKey = savedKey
                }
            }
        }
    }
}