import SwiftUI

// Settings View
struct SettingsView: View {
    @State private var showMissingTranslations = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("App Settings")) {
                    Toggle("Enable Notifications", isOn: .constant(true))
                    Toggle("Dark Mode", isOn: .constant(false))
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
        }
    }
} 