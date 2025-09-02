import SwiftUI
import WebKit

struct Resource: Identifiable, Codable {
    var id = UUID()
    var name: String
    var url: String
    var faviconURL: String?
    var customColor: String? // Store as hex string
    
    var color: Color {
        if let customColor = customColor {
            return Color(hex: customColor) ?? .blue
        }
        return .blue
    }
    
    init(name: String, url: String, customColor: String? = nil) {
        self.name = name
        self.url = url
        self.faviconURL = nil
        self.customColor = customColor
    }
}

struct ResourcesView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var resources: [Resource] = []
    @State private var showingAddResource = false
    @State private var editingResource: Resource?
    
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(resources) { resource in
                    ResourceWidget(resource: resource, action: {
                        openResource(resource)
                    }, onEdit: {
                        editingResource = resource
                    }, onDelete: {
                        deleteResource(resource)
                    })
                }
                
                // Add Resource Button
                Button {
                    showingAddResource = true
                } label: {
                    AddResourceWidget()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddResource = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .font(.forma(.title2))
                }
            }
        }
        .sheet(isPresented: $showingAddResource) {
            AddResourceView { resource in
                addResource(resource)
            }
            .environmentObject(themeManager)
        }
        .sheet(item: $editingResource) { resource in
            EditResourceView(resource: resource) { updatedResource in
                updateResource(updatedResource)
            }
            .environmentObject(themeManager)
        }
        .onAppear {
            loadResources()
        }
    }
    
    private func addResource(_ resource: Resource) {
        var newResource = resource
        // Use higher quality favicon
        if let url = URL(string: resource.url) {
            let domain = url.host ?? ""
            // Try multiple favicon sources for better quality
            newResource.faviconURL = "https://www.google.com/s2/favicons?domain=\(domain)&sz=64"
        }
        resources.append(newResource)
        saveResources()
    }
    
    private func updateResource(_ resource: Resource) {
        if let index = resources.firstIndex(where: { $0.id == resource.id }) {
            var updatedResource = resource
            if let url = URL(string: resource.url) {
                let domain = url.host ?? ""
                updatedResource.faviconURL = "https://www.google.com/s2/favicons?domain=\(domain)&sz=64"
            }
            resources[index] = updatedResource
            saveResources()
        }
    }
    
    private func deleteResource(_ resource: Resource) {
        resources.removeAll { $0.id == resource.id }
        saveResources()
    }
    
    private func openResource(_ resource: Resource) {
        guard let url = URL(string: resource.url) else { return }
        UIApplication.shared.open(url)
    }
    
    private func saveResources() {
        if let encoded = try? JSONEncoder().encode(resources) {
            UserDefaults.standard.set(encoded, forKey: "savedResources")
        }
    }
    
    private func loadResources() {
        if let savedData = UserDefaults.standard.data(forKey: "savedResources"),
           let decodedResources = try? JSONDecoder().decode([Resource].self, from: savedData) {
            resources = decodedResources
        } else {
            // Add some default resources
            resources = [
                Resource(name: "Google Scholar", url: "https://scholar.google.com"),
                Resource(name: "Khan Academy", url: "https://www.khanacademy.org"),
                Resource(name: "Coursera", url: "https://www.coursera.org"),
                Resource(name: "GitHub", url: "https://github.com")
            ]
            // Set favicons for defaults
            for i in 0..<resources.count {
                if let url = URL(string: resources[i].url) {
                    let domain = url.host ?? ""
                    resources[i].faviconURL = "https://www.google.com/s2/favicons?domain=\(domain)&sz=64"
                }
            }
            saveResources()
        }
    }
}

struct ResourceWidget: View {
    let resource: Resource
    let action: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Group {
                    if let faviconURL = resource.faviconURL {
                        AsyncImage(url: URL(string: faviconURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Image(systemName: "globe")
                                .font(.forma(.body))
                                .foregroundColor(resource.color)
                        }
                    } else {
                        Image(systemName: "globe")
                            .font(.forma(.body))
                            .foregroundColor(resource.color)
                    }
                }
                .frame(width: 20, height: 20)
                
                Text(resource.name)
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .padding(12)
            .background(resource.customColor != nil ? resource.color.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(resource.customColor != nil ? resource.color : themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct AddResourceWidget: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .font(.forma(.title2))
                .foregroundColor(themeManager.currentTheme.primaryColor)
            
            Text("Add Resource")
                .font(.forma(.caption, weight: .medium))
                .foregroundColor(themeManager.currentTheme.primaryColor)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .padding(12)
        .background(themeManager.currentTheme.primaryColor.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.currentTheme.primaryColor, lineWidth: 2)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
        )
    }
}

struct AddResourceView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var name = ""
    @State private var url = ""
    @State private var selectedColor: Color = .blue
    @State private var useCustomColor = false
    
    let onAdd: (Resource) -> Void
    
    private let predefinedColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Resource Name", text: $name)
                        .font(.forma(.headline))
                    
                    TextField("Website URL", text: $url)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                } header: {
                    Text("Resource Details")
                        .font(.forma(.caption, weight: .medium))
                } footer: {
                    Text("Enter the full URL including https://")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Toggle("Use Custom Color", isOn: $useCustomColor)
                        .font(.forma(.body))
                    
                    if useCustomColor {
                        ColorPicker("Button Color", selection: $selectedColor, supportsOpacity: false)
                            .font(.forma(.body))
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(predefinedColors, id: \.self) { color in
                                    Circle()
                                        .fill(color)
                                        .frame(width: 30, height: 30)
                                        .onTapGesture {
                                            selectedColor = color
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                        )
                                        .padding(.horizontal, 2)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                } header: {
                    Text("Customization")
                        .font(.forma(.caption, weight: .medium))
                }
                
                Section {
                    HStack {
                        Text("Preview")
                            .font(.forma(.body))
                        Spacer()
                        if !name.isEmpty && !url.isEmpty {
                            VStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.forma(.body))
                                    .foregroundColor(useCustomColor ? selectedColor : themeManager.currentTheme.primaryColor)
                                Text(name)
                                    .font(.forma(.caption, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding(8)
                            .background(useCustomColor ? selectedColor.opacity(0.1) : Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(useCustomColor ? selectedColor : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .navigationTitle("Add Resource")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.forma(.body))
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        var urlString = url.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                            urlString = "https://" + urlString
                        }
                        
                        let customColorHex = useCustomColor ? selectedColor.toHex() : nil
                        let resource = Resource(name: name.trimmingCharacters(in: .whitespacesAndNewlines), url: urlString, customColor: customColorHex)
                        onAdd(resource)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .font(.forma(.body))
                    .foregroundColor(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : themeManager.currentTheme.primaryColor)
                }
            }
        }
    }
}

struct EditResourceView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var name: String
    @State private var url: String
    @State private var selectedColor: Color
    @State private var useCustomColor: Bool
    
    let resource: Resource
    let onUpdate: (Resource) -> Void
    
    private let predefinedColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown
    ]
    
    init(resource: Resource, onUpdate: @escaping (Resource) -> Void) {
        self.resource = resource
        self.onUpdate = onUpdate
        self._name = State(initialValue: resource.name)
        self._url = State(initialValue: resource.url)
        self._selectedColor = State(initialValue: resource.color)
        self._useCustomColor = State(initialValue: resource.customColor != nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Resource Name", text: $name)
                        .font(.forma(.headline))
                    
                    TextField("Website URL", text: $url)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                } header: {
                    Text("Resource Details")
                        .font(.forma(.caption, weight: .medium))
                }
                
                Section {
                    Toggle("Use Custom Color", isOn: $useCustomColor)
                        .font(.forma(.body))
                    
                    if useCustomColor {
                        ColorPicker("Button Color", selection: $selectedColor, supportsOpacity: false)
                            .font(.forma(.body))
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(predefinedColors, id: \.self) { color in
                                    Circle()
                                        .fill(color)
                                        .frame(width: 30, height: 30)
                                        .onTapGesture {
                                            selectedColor = color
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                        )
                                        .padding(.horizontal, 2)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                } header: {
                    Text("Customization")
                        .font(.forma(.caption, weight: .medium))
                }
                
                Section {
                    HStack {
                        Text("Preview")
                            .font(.forma(.body))
                        Spacer()
                        if !name.isEmpty && !url.isEmpty {
                            VStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.forma(.body))
                                    .foregroundColor(useCustomColor ? selectedColor : themeManager.currentTheme.primaryColor)
                                Text(name)
                                    .font(.forma(.caption, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding(8)
                            .background(useCustomColor ? selectedColor.opacity(0.1) : Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(useCustomColor ? selectedColor : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .navigationTitle("Edit Resource")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.forma(.body))
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var urlString = url.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                            urlString = "https://" + urlString
                        }
                        
                        var updatedResource = resource
                        updatedResource.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        updatedResource.url = urlString
                        updatedResource.customColor = useCustomColor ? selectedColor.toHex() : nil
                        
                        onUpdate(updatedResource)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .font(.forma(.body))
                    .foregroundColor(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : themeManager.currentTheme.primaryColor)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        ResourcesView()
            .environmentObject(ThemeManager())
    }
}