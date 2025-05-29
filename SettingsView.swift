import SwiftUI

struct SettingsView: View {
    @AppStorage("d2lLink") private var d2lLink: String = "https://d2l.youruniversity.edu"
    @AppStorage("usePercentageGrades") private var usePercentageGrades: Bool = false
    @AppStorage("showCurrentGPA") private var showCurrentGPA: Bool = true

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Grade Display Settings
                gradeDisplaySection
                
                // D2L Configuration
                d2lConfigSection
                
                // Resources Section
                resourcesSection
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var gradeDisplaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Grade Display")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                SettingToggleRow(
                    title: "Show Current Grade",
                    subtitle: "Display your current grade on the Courses button",
                    isOn: $showCurrentGPA,
                    icon: "graduationcap.fill",
                    color: .primaryGreen
                )
                
                if showCurrentGPA {
                    SettingToggleRow(
                        title: "Use Percentage Grades",
                        subtitle: "Show percentages instead of GPA scale",
                        isOn: $usePercentageGrades,
                        icon: "percent",
                        color: .secondaryGreen
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var d2lConfigSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("D2L Configuration")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("D2L Portal URL")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                TextField("Enter D2L URL", text: $d2lLink)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                
                Text("Ensure the URL starts with 'https://' or 'http://'")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resources")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.tertiaryGreen.opacity(0.7))
                
                Text("Resource Management")
                    .font(.headline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text("Resource management functionality will be added in a future update.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct SettingToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: color))
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)

    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
    }

}

