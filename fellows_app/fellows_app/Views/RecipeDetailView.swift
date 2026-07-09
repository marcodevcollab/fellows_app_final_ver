import SwiftData
import SwiftUI

struct RecipeDetailView: View {
  let result: RecipeResult

  @Environment(\.modelContext) private var modelContext
  @Query(sort: \PantryItem.name) private var pantryItems: [PantryItem]

  @State private var activeAlert: RecipeDetailAlert?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 10) {
          Label(
            result.source.rawValue,
            systemImage: result.source == .appleIntelligence ? "apple.intelligence" : "info.circle"
          )
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.tint)

          Text(result.recipe.title)
            .font(.custom("SingleDay-Regular", size: 38))

          Text(result.recipe.summary)
            .font(.body)
            .foregroundStyle(.secondary)

          HStack(spacing: 16) {
            Label(result.recipe.preparationTime, systemImage: "clock")
            Label(result.recipe.servings, systemImage: "person.2")
          }
          .font(.subheadline)
          .foregroundStyle(.secondary)
        }

        if let statusMessage = result.statusMessage {
          FellowsCard {
            Label(statusMessage, systemImage: "info.circle.fill")
              .font(.subheadline)
          }
        }

        recipeSection(title: "Ingredients", systemImage: "basket.fill") {
          ForEach(result.recipe.ingredients, id: \.self) { ingredient in
            Label(ingredient, systemImage: "circle.fill")
              .symbolRenderingMode(.hierarchical)
              .font(.body)
          }
        }

        if !result.recipe.missingIngredients.isEmpty {
          recipeSection(title: "Missing ingredients", systemImage: "cart.badge.plus") {
            ForEach(result.recipe.missingIngredients, id: \.self) { ingredient in
              HStack(spacing: 12) {
                Text(ingredient)
                  .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                  addMissingIngredient(ingredient)
                } label: {
                  Image(
                    systemName: isIngredientInPantry(ingredient)
                      ? "checkmark.circle.fill"
                      : "plus.circle.fill"
                  )
                  .font(.title3)
                }
                .buttonStyle(.borderless)
                .disabled(isIngredientInPantry(ingredient))
                .accessibilityLabel(
                  isIngredientInPantry(ingredient)
                    ? "\(ingredient) is already in your pantry"
                    : "Add \(ingredient) to your pantry"
                )
              }
            }
          }
        }

        recipeSection(title: "Method", systemImage: "list.number") {
          ForEach(Array(result.recipe.instructions.enumerated()), id: \.offset) {
            index, instruction in
            HStack(alignment: .top, spacing: 12) {
              Text("\(index + 1)")
                .font(.caption.bold())
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.15), in: Circle())
              Text(instruction)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }

        Text(result.recipe.safetyNote)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .padding(.bottom, 24)
      }
      .padding()
    }
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Recipe")
          .font(.custom("SingleDay-Regular", size: 28))
      }
    }
    .alert(item: $activeAlert) { alert in
      Alert(
        title: Text(alert.title),
        message: Text(alert.message),
        dismissButton: .default(Text("OK"))
      )
    }
  }

  private func isIngredientInPantry(_ ingredient: String) -> Bool {
    let name = pantryIngredientName(from: ingredient)
    return pantryItems.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
  }

  private func addMissingIngredient(_ ingredient: String) {
    let name = pantryIngredientName(from: ingredient)
    guard !name.isEmpty, !isIngredientInPantry(name) else { return }

    let pantryItem = PantryItem(name: name)
    modelContext.insert(pantryItem)

    do {
      try modelContext.save()
      activeAlert = .ingredientAdded
    } catch {
      modelContext.delete(pantryItem)
      activeAlert = .ingredientCouldNotBeAdded
    }
  }

  private func pantryIngredientName(from ingredient: String) -> String {
    ingredient
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "•-–—"))
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func recipeSection<Content: View>(
    title: String,
    systemImage: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(title, systemImage: systemImage)
        .font(.custom("SingleDay-Regular", size: 27))
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private enum RecipeDetailAlert: Hashable, Identifiable {
  case ingredientAdded
  case ingredientCouldNotBeAdded

  var id: Self { self }

  var title: String {
    switch self {
    case .ingredientAdded:
      return "Great!"
    case .ingredientCouldNotBeAdded:
      return "Something went wrong"
    }
  }

  var message: String {
    switch self {
    case .ingredientAdded:
      return "You added another item to your pantry :)"
    case .ingredientCouldNotBeAdded:
      return "The ingredient could not be saved. Please try again."
    }
  }
}
