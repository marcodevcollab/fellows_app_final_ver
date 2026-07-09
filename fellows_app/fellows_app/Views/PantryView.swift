import SwiftData
import SwiftUI

struct PantryView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var profiles: [UserProfile]
  @Query(sort: \PantryItem.name) private var pantryItems: [PantryItem]

  @State private var showingAddIngredient = false
  @State private var generatedRecipe: RecipeResult?
  @State private var isGenerating = false
  @State private var generationErrorMessage: String?

  var body: some View {
    NavigationStack {
      Group {
        if pantryItems.isEmpty {
          ContentUnavailableView(
            "Your pantry is empty",
            systemImage: "cabinet",
            description: Text(
              "Add the ingredients you already have, then Fellows can suggest a tailored recipe.")
          )
        } else {
          List {
            Section("Available ingredients") {
              ForEach(pantryItems) { item in
                HStack(spacing: 12) {
                  Label(item.name, systemImage: "leaf.fill")

                  Spacer()

                  Button(role: .destructive) {
                    deleteItem(item)
                  } label: {
                    Image(systemName: "minus.circle.fill")
                      .font(.title3)
                  }
                  .buttonStyle(.borderless)
                  .accessibilityLabel("Remove \(item.name)")
                  .accessibilityHint("Removes this ingredient from your pantry")
                }
              }
              .onDelete(perform: deleteItems)
            }
          }
        }
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("Pantry")
            .font(.custom("SingleDay-Regular", size: 28))
        }
        ToolbarItem(placement: .primaryAction) {
          Button("Add ingredient", systemImage: "plus") {
            showingAddIngredient = true
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        Button {
          Task { await generateRecipe() }
        } label: {
          if isGenerating {
            HStack {
              ProgressView()
              Text("Generating…")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
          } else {
            PrimaryActionButtonLabel(title: "Generate Recipe", systemImage: "sparkles")
          }
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 0.56, green: 0.75, blue: 0.51))
        .disabled(pantryItems.isEmpty || isGenerating)
        .padding(.horizontal)
        .padding(.top, 8)
        .background(.bar)
      }
      .sheet(isPresented: $showingAddIngredient) {
        AddIngredientView()
      }
      .sheet(item: $generatedRecipe) { result in
        NavigationStack {
          RecipeDetailView(result: result)
            .toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button("Done") { generatedRecipe = nil }
              }
            }
        }
      }
      .alert(
        "Unable to Generate Recipe",
        isPresented: Binding(
          get: { generationErrorMessage != nil },
          set: { if !$0 { generationErrorMessage = nil } }
        )
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(generationErrorMessage ?? "Please try again.")
      }
    }
  }

  private func deleteItems(at offsets: IndexSet) {
    for index in offsets {
      modelContext.delete(pantryItems[index])
    }
    try? modelContext.save()
  }

  private func deleteItem(_ item: PantryItem) {
    modelContext.delete(item)
    try? modelContext.save()
  }

  private func generateRecipe() async {
    isGenerating = true
    generationErrorMessage = nil
    defer { isGenerating = false }

    do {
      generatedRecipe = try await RecipeGenerationService.generateRecipe(
        kind: .pantry,
        profile: profiles.first,
        pantryItems: pantryItems
      )
    } catch is CancellationError {
      return
    } catch {
      generationErrorMessage = error.localizedDescription
    }
  }
}

private struct AddIngredientView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \PantryItem.name) private var pantryItems: [PantryItem]

  @State private var ingredientName = ""

  private var trimmedName: String {
    ingredientName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var isDuplicate: Bool {
    pantryItems.contains { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Ingredient") {
          TextField("e.g. Rice", text: $ingredientName)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .onSubmit(save)
        }

        if isDuplicate {
          Text("This ingredient is already in your pantry.")
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("Add Ingredient")
            .font(.custom("SingleDay-Regular", size: 24))
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add", action: save)
            .disabled(trimmedName.isEmpty || isDuplicate)
        }
      }
    }
  }

  private func save() {
    guard !trimmedName.isEmpty, !isDuplicate else { return }
    modelContext.insert(PantryItem(name: trimmedName))
    try? modelContext.save()
    dismiss()
  }
}
