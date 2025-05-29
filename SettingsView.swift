import SwiftUI

struct SettingsView: View {
    @AppStorage("d2lLink") private var d2lLink: String = "https://d2l.youruniversity.edu" // Default URL

    var body: some View {
        Form {
            Section(header: Text("D2L Configuration")) {
                HStack {
                    Text("D2L URL:")
                    TextField("Enter D2L URL", text: $d2lLink)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                }
                Text("Ensure the URL starts with 'https://' or 'http://'")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Section(header: Text("Manage Resources")) {
                Text("Resource management functionality will be added here.")
                // TODO: Add UI for managing resources
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
    }
}