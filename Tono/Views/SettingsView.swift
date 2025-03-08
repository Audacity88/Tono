import SwiftUI

// Settings View
struct SettingsView: View {
    @State private var showMissingTranslations = false
    @State private var selectedModel: ModelType = ModelManager.shared.currentModelType
    @State private var apiKey: String = UserDefaults.standard.string(forKey: "FluentAPIKey") ?? ""
    @State private var showingAPIKeySaved = false
    @State private var selectedLanguageID: Int = UserDefaults.standard.integer(forKey: "FluentLanguageID") != 0 ? 
        UserDefaults.standard.integer(forKey: "FluentLanguageID") : PronunciationAPI.LanguageID.english
    
    // Reference to the shared PronunciationAPI instance
    @StateObject private var pronunciationAPI = PronunciationAPI()
    
    // Environment object to access the focus state
    @Environment(\.colorScheme) private var colorScheme
    
    // For keyboard dismissal
    @FocusState private var isAPIKeyFieldFocused: Bool
    
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
                
                Section(header: Text("Pronunciation API")) {
                    VStack(alignment: .leading) {
                        Text("RapidAPI Key for thefluent.me")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("Enter RapidAPI Key", text: $apiKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.password)
                            .padding(.vertical, 4)
                            .focused($isAPIKeyFieldFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                saveAPIKey()
                            }
                        
                        Button(action: saveAPIKey) {
                            Text("Save API Key")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.top, 4)
                        
                        if showingAPIKeySaved {
                            Text("API Key saved!")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.top, 4)
                        }
                        
                        Text("Sign up for a RapidAPI key at rapidapi.com and subscribe to thefluent.me API")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                            .multilineTextAlignment(.leading)
                        
                        Link("Get API Key on RapidAPI", destination: URL(string: "https://rapidapi.com/thefluentme/api/thefluent-me")!)
                            .font(.caption)
                            .padding(.top, 4)
                    }
                    
                    Picker("Pronunciation Language", selection: $selectedLanguageID) {
                        Text("English").tag(PronunciationAPI.LanguageID.english)
                        Text("Chinese (Simplified)").tag(PronunciationAPI.LanguageID.chineseSimplified)
                        Text("Chinese (Traditional)").tag(PronunciationAPI.LanguageID.chineseTraditional)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedLanguageID) { newValue in
                        pronunciationAPI.setLanguageID(newValue)
                    }
                    .padding(.top, 8)
                    
                    if apiKey.isEmpty {
                        Text("No API key provided. App will use simulation mode for pronunciation assessment.")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
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
                selectedLanguageID = pronunciationAPI.currentLanguageID
            }
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        isAPIKeyFieldFocused = false
                    }
                }
            }
        }
    }
    
    private func saveAPIKey() {
        // Dismiss keyboard
        isAPIKeyFieldFocused = false
        
        // Save API key to UserDefaults
        UserDefaults.standard.set(apiKey, forKey: "FluentAPIKey")
        
        // Update the API key in the PronunciationAPI
        pronunciationAPI.setAPIKey(apiKey)
        
        // Show confirmation
        showingAPIKeySaved = true
        
        // Hide confirmation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingAPIKeySaved = false
        }
    }
}

