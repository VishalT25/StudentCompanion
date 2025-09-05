import SwiftUI
import WebKit
import LinkPresentation

// MARK: - Resource Model
struct Resource: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var url: String
    var faviconURL: String?
    var customColor: String? // Stored as hex string

    var color: Color {
        if let customColor, let color = Color(hex: customColor) {
            return color
        }
        return .accentColor
    }
}

// MARK: - Resources Manager
class ResourcesManager: ObservableObject {
    @Published var resources: [Resource] = []
    private let storageKey = "savedResources_v2"

    init() {
        loadResources()
    }

    func addResource(_ resource: Resource) {
        var newResource = resource
        if let faviconURL = generateFaviconURL(for: resource.url) {
            newResource.faviconURL = faviconURL
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            resources.append(newResource)
        }
        saveResources()
    }

    func updateResource(_ resource: Resource) {
        guard let index = resources.firstIndex(where: { $0.id == resource.id }) else { return }
        var updatedResource = resource
        if let faviconURL = generateFaviconURL(for: resource.url) {
            updatedResource.faviconURL = faviconURL
        }
        resources[index] = updatedResource
        saveResources()
    }

    func deleteResource(id: UUID) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            resources.removeAll { $0.id == id }
        }
        saveResources()
    }
    
    private func generateFaviconURL(for urlString: String) -> String? {
        guard let url = URL(string: urlString), let host = url.host else { return nil }
        return "https://www.google.com/s2/favicons?domain=\(host)&sz=128"
    }

    private func saveResources() {
        if let encoded = try? JSONEncoder().encode(resources) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadResources() {
        if let savedData = UserDefaults.standard.data(forKey: storageKey),
           let decodedResources = try? JSONDecoder().decode([Resource].self, from: savedData) {
            resources = decodedResources
            return
        }
        
        // Add some default resources for first-time users
        self.resources = [
            Resource(name: "Google Scholar", url: "https://scholar.google.com", customColor: Color.blue.toHex()),
            Resource(name: "Khan Academy", url: "https://www.khanacademy.org", customColor: Color.green.toHex()),
            Resource(name: "Coursera", url: "https://www.coursera.org", customColor: Color.purple.toHex()),
            Resource(name: "GitHub", url: "https://github.com", customColor: Color.gray.toHex())
        ]
        // Set favicons for defaults
        for i in 0..<resources.count {
            resources[i].faviconURL = generateFaviconURL(for: resources[i].url)
        }
        saveResources()
    }
}


// MARK: - Main Resources View
struct ResourcesView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var resourcesManager = ResourcesManager()
    @State private var showingAddResource = false
    @State private var editingResource: Resource?
    @State private var searchText = ""
    @State private var animationOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var filteredResources: [Resource] {
        if searchText.isEmpty {
            return resourcesManager.resources
        } else {
            return resourcesManager.resources.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        ZStack {
            SpectacularBackground(themeManager: themeManager)
            
            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                ScrollView {
                    contentView
                        .padding(.top, 10)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddResource) {
            AddResourceView(resourcesManager: resourcesManager)
                .environmentObject(themeManager)
        }
        .sheet(item: $editingResource) { resource in
            EditResourceView(resource: resource, resourcesManager: resourcesManager)
                .environmentObject(themeManager)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if !filteredResources.isEmpty {
            resourcesGrid
        } else if searchText.isEmpty {
            emptyStateView
        } else {
            noSearchResultsView
        }
    }

    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward.circle.fill")
                        .font(.forma(.title2, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .background(Circle().fill(.regularMaterial).padding(2))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                }

                Spacer()
                
                Text("Resources")
                    .font(.forma(.largeTitle, weight: .bold))
                
                Spacer()

                Button {
                    showingAddResource = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.forma(.title2, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .background(Circle().fill(.regularMaterial).padding(2))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                }
            }
            .padding(.top, 10)

            SearchBar(text: $searchText, placeholder: "Search resources...")
                .environmentObject(themeManager)
        }
    }

    private var resourcesGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(filteredResources.enumerated()), id: \.element.id) { index, resource in
                ResourceWidget(
                    resource: resource,
                    onEdit: { editingResource = resource },
                    onDelete: { resourcesManager.deleteResource(id: resource.id) }
                )
                .environmentObject(themeManager)
                .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.05), value: filteredResources)
            }
            
            AddResourceWidget { showingAddResource = true }
                .environmentObject(themeManager)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 50)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.square.filled.on.square")
                .font(.system(size: 60))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .symbolRenderingMode(.hierarchical)
            
            Text("Your Academic Toolkit")
                .font(.forma(.title2, weight: .bold))
            
            Text("Add links to your favorite study sites, research tools, and online resources to keep them handy.")
                .font(.forma(.subheadline))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            Button { showingAddResource = true } label: {
                Label("Add First Resource", systemImage: "plus")
                    .font(.forma(.body, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Capsule().fill(themeManager.currentTheme.primaryColor))
                    .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.4), radius: 10, y: 5)
            }
        }
        .padding(.top, 80)
    }

    private var noSearchResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Results for '\(searchText)'")
                .font(.forma(.headline, weight: .semibold))
            
            Text("Check the spelling or try a different keyword.")
                .font(.forma(.subheadline))
                .foregroundColor(.secondary)
        }
        .padding(.top, 80)
    }
}

// MARK: - Resource Widgets
struct ResourceWidget: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let resource: Resource
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: openResource) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        // 1. The colored background circle
                        Circle()
                            .fill(resource.color.opacity(0.2))

                        // 2. The favicon, clipped to a circle
                        AsyncImage(url: URL(string: resource.faviconURL ?? "")) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(Circle()) // Clip the image itself into a circle
                            case .failure:
                                Image(systemName: "globe")
                                    .foregroundColor(resource.color)
                            case .empty:
                                ProgressView()
                                    .tint(resource.color)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .padding(8) // Padding to make the icon smaller than the background
                    }
                    .frame(width: 44, height: 44)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(resource.name)
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(URL(string: resource.url)?.host ?? "")
                        .font(.forma(.caption2))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(12)
            .frame(height: 120)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(resource.color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(SquishableButtonStyle(tint: resource.color))
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func openResource() {
        guard let url = URL(string: resource.url) else { return }
        UIApplication.shared.open(url)
    }
}

struct AddResourceWidget: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.6))
                    .background(.ultraThinMaterial.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                
                VStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.forma(.title, weight: .semibold))
                    Text("Add Resource")
                        .font(.forma(.footnote, weight: .semibold))
                }
                .foregroundColor(themeManager.currentTheme.primaryColor)
            }
            .frame(height: 120)
        }
        .buttonStyle(SquishableButtonStyle(tint: themeManager.currentTheme.primaryColor))
    }
}

// MARK: - Add/Edit Views
struct AddResourceView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject var resourcesManager: ResourcesManager
    
    @State private var name: String = ""
    @State private var url: String = ""
    @State private var selectedColor: Color = .blue
    @State private var isFetchingMetadata = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Resource Details")) {
                    TextField("Name (e.g., Khan Academy)", text: $name)
                    
                    HStack {
                        TextField("URL (e.g., https://...)", text: $url)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: url, perform: fetchMetadata)
                        
                        if isFetchingMetadata {
                            ProgressView().padding(.leading, 5)
                        }
                    }
                }
                
                Section(header: Text("Customization")) {
                    ColorPicker("Accent Color", selection: $selectedColor, supportsOpacity: false)
                }
                
                if !name.isEmpty {
                    Section(header: Text("Preview")) {
                        ResourceWidget(
                            resource: Resource(name: name, url: url, customColor: selectedColor.toHex()),
                            onEdit: {},
                            onDelete: {}
                        )
                        .environmentObject(themeManager)
                        .buttonStyle(.plain) // Disable button action in preview
                    }
                }
            }
            .navigationTitle("Add Resource")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addResource() }
                        .disabled(name.isEmpty || url.isEmpty)
                }
            }
        }
    }
    
    private func fetchMetadata(for urlString: String) {
        guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else { return }
        
        isFetchingMetadata = true
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { metadata, error in
            DispatchQueue.main.async {
                isFetchingMetadata = false
                if let metadata = metadata, name.isEmpty {
                    name = metadata.title ?? ""
                }
            }
        }
    }
    
    private func addResource() {
        var urlString = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        let resource = Resource(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            url: urlString,
            customColor: selectedColor.toHex()
        )
        resourcesManager.addResource(resource)
        dismiss()
    }
}

struct EditResourceView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject var resourcesManager: ResourcesManager
    
    @State private var resource: Resource
    
    init(resource: Resource, resourcesManager: ResourcesManager) {
        _resource = State(initialValue: resource)
        self.resourcesManager = resourcesManager
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Resource Details")) {
                    TextField("Name", text: $resource.name)
                    TextField("URL", text: $resource.url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Customization")) {
                    ColorPicker("Accent Color", selection: Binding(
                        get: { resource.color },
                        set: { resource.customColor = $0.toHex() }
                    ), supportsOpacity: false)
                }
                
                Section(header: Text("Preview")) {
                    ResourceWidget(resource: resource, onEdit: {}, onDelete: {})
                        .environmentObject(themeManager)
                        .buttonStyle(.plain)
                }
            }
            .navigationTitle("Edit Resource")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { updateResource() }
                        .disabled(resource.name.isEmpty || resource.url.isEmpty)
                }
            }
        }
    }
    
    private func updateResource() {
        var urlString = resource.url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        resource.url = urlString
        resource.name = resource.name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        resourcesManager.updateResource(resource)
        dismiss()
    }
}

// MARK: - Helper Components & Styles
struct SearchBar: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
            TextField(placeholder, text: $text)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
            }
        }
        .font(.forma(.body))
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
        )
    }
}

struct SquishableButtonStyle: ButtonStyle {
    var tint: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .shadow(color: tint.opacity(configuration.isPressed ? 0.2 : 0.4),
                    radius: configuration.isPressed ? 4 : 8,
                    y: configuration.isPressed ? 2 : 5)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

// Preview
#Preview {
    ResourcesView()
        .environmentObject(ThemeManager())
}