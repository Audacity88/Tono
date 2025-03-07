import SwiftUI

// Settings View
struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("App Settings")) {
                    Toggle("Enable Notifications", isOn: .constant(true))
                    Toggle("Dark Mode", isOn: .constant(false))
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
        }
    }
} 