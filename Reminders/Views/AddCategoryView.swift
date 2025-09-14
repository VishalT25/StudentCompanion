import SwiftUI

struct AddCategoryView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var categoryName: String = ""
    @State private var selectedColor: Color = .blue
    @State private var showValidationErrors = false
    @State private var isLoading = false
    @State private var saveSuccess = false
    @State private var bounceAnimation: Double = 0
    
    @FocusState private var isFocused: Bool
    
    private let availableColors: [Color] = [
        .blue, .green, .orange, .red, .purple, .pink,
        .teal, .indigo, .mint, .cyan, .yellow, .brown
    ]
    
    private var isFormValid: Bool {
        !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("New Category")
                        .font(.largeTitle)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [selectedColor, selectedColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Organize your reminders with custom categories")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                VStack(spacing: 20) {
                    // Category Name Field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "tag.fill")
                                .font(.subheadline)
                                .foregroundColor(isFocused ? selectedColor : .secondary)
                            Text("Category Name")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        
                        TextField("e.g., Work, School, Personal", text: $categoryName)
                            .focused($isFocused)
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                isFocused ? selectedColor.opacity(0.6) :
                                                (!isFormValid && showValidationErrors) ? .red.opacity(0.6) :
                                                Color.Color_secondary.opacity(0.3),
                                                lineWidth: isFocused ? 2 : 1
                                            )
                                    )
                            )
                        
                        if !isFormValid && showValidationErrors {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Text("Please enter a category name")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // Color Selection
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "paintpalette.fill")
                                .font(.subheadline)
                                .foregroundColor(selectedColor)
                            Text("Category Color")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(availableColors, id: \.self) { color in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedColor = color
                                    }
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(color.opacity(0.3), lineWidth: 1)
                                        )
                                        .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                                        .shadow(
                                            color: selectedColor == color ? color.opacity(0.3) : .clear,
                                            radius: selectedColor == color ? 8 : 0,
                                            x: 0,
                                            y: selectedColor == color ? 4 : 0
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Save Button
                Button {
                    saveCategory()
                } label: {
                    HStack(spacing: 12) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else if saveSuccess {
                            Image(systemName: "checkmark")
                                .font(.title2)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        
                        if !isLoading {
                            Text(saveSuccess ? "Added!" : "Create Category")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: saveSuccess ? [.green, .green.opacity(0.8)] :
                                           isFormValid ? [selectedColor, selectedColor.opacity(0.8)] :
                                           [Color.Color_secondary.opacity(0.6), Color.Color_secondary.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(
                                color: saveSuccess ? .green.opacity(0.4) :
                                       isFormValid ? selectedColor.opacity(0.4) : .clear,
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                            .scaleEffect(bounceAnimation * 0.05 + 0.95)
                    )
                }
                .disabled(!isFormValid || isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
            }
            .onChange(of: saveSuccess) { _, newValue in
                if newValue {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        bounceAnimation = 1.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func saveCategory() {
        guard isFormValid else {
            showValidationErrors = true
            return
        }
        
        isLoading = true
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let newCategory = Category(
                name: categoryName.trimmingCharacters(in: .whitespacesAndNewlines),
                color: selectedColor
            )
            
            viewModel.addCategory(newCategory)
            
            isLoading = false
            saveSuccess = true
            
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        }
    }
}