import SwiftUI

// Settings View
struct SettingsView: View {
    @State private var showMissingTranslations = false
    @State private var selectedModel: ModelType = ModelManager.shared.currentModelType
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("App Settings")) {
                    Toggle("Enable Notifications", isOn: .constant(true))
                    Toggle("Dark Mode", isOn: .constant(false))
                }
                
                Section(header: Text("Model Selection")) {
                    Picker("Object Recognition Model", selection: $selectedModel) {
                        ForEach(ModelType.allCases) { model in
                            Text(model.rawValue).tag(model)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedModel) { newValue in
                        ModelManager.shared.currentModelType = newValue
                    }
                    
                    // Description of the selected model
                    Text(selectedModel.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                
                Section(header: Text("Tools")) {
                    Button(action: {
                        showMissingTranslations = true
                    }) {
                        HStack {
                            Image(systemName: "character.book.closed")
                            Text("Check Missing Translations")
                        }
                    }
                }
                
                Section(header: Text("Account")) {
                    Text("Sign In")
                    Text("Privacy Policy")
                    Text("Terms of Service")
                }
                
                Section(header: Text("About")) {
                    Text("Version 1.0.0")
                    Text("© 2025 Dan Gilles")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showMissingTranslations) {
                MissingTranslationsView()
            }
            .onAppear {
                // Update the selected model when the view appears
                selectedModel = ModelManager.shared.currentModelType
            }
        }
    }
}

