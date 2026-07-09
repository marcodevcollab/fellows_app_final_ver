import SwiftData
import SwiftUI

struct CookView: View {
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 6) {
            Text("How much time do you have?")
              .font(.custom("SingleDay-Regular", size: 38))
            Text(
              "Choose a time range. Fellows will then ask whether you are preparing lunch or dinner."
            )
            .foregroundStyle(.secondary)
          }

          ForEach(CookingTimeOption.allCases) { option in
            NavigationLink(value: option) {
              FellowsCard {
                HStack(spacing: 16) {
                  Image(systemName: option.symbolName)
                    .font(.title2)
                    .frame(width: 36)
                    .foregroundStyle(.tint)

                  VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                      .font(.headline)
                    Text(option.subtitle)
                      .font(.subheadline)
                      .foregroundStyle(.secondary)
                  }

                  Spacer()

                  Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                }
              }
            }
            .buttonStyle(.plain)
          }

          Text(RecipeGenerationService.availabilityDescription)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .padding()
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("Cook")
            .font(.custom("SingleDay-Regular", size: 28))
        }
      }
      .navigationDestination(for: CookingTimeOption.self) { option in
        CookMealSelectionView(selectedTime: option)
      }
    }
  }
}

private struct CookMealSelectionView: View {
  let selectedTime: CookingTimeOption

  @Query private var profiles: [UserProfile]
  @Query(sort: \PantryItem.name) private var pantryItems: [PantryItem]

  @State private var generatedRecipe: RecipeResult?
  @State private var selectedMeal: DailyMeal?
  @State private var isGenerating = false
  @State private var generationErrorMessage: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          Text("What are you cooking?")
            .font(.custom("SingleDay-Regular", size: 38))
          Text("Choose the meal for your \(selectedTime.title) recipe.")
            .foregroundStyle(.secondary)
        }

        mealButton(for: .lunch)
        mealButton(for: .dinner)

        Text(
          "The generated recipe uses your current profile restrictions and prefers ingredients from your Pantry."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
      }
      .padding()
    }
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("Meal")
          .font(.custom("SingleDay-Regular", size: 28))
      }
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

  private func mealButton(for meal: DailyMeal) -> some View {
    Button {
      selectedMeal = meal
      Task { await generateRecipe(for: meal) }
    } label: {
      FellowsCard {
        HStack(spacing: 16) {
          Image(systemName: symbolName(for: meal))
            .font(.title2)
            .frame(width: 36)
            .foregroundStyle(.tint)

          VStack(alignment: .leading, spacing: 4) {
            Text(meal.title)
              .font(.headline)
            Text(subtitle(for: meal))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Spacer()

          if isGenerating && selectedMeal == meal {
            ProgressView()
          } else {
            Image(systemName: "chevron.right")
              .foregroundStyle(.tertiary)
          }
        }
      }
    }
    .buttonStyle(.plain)
    .disabled(isGenerating)
  }

  private func generateRecipe(for meal: DailyMeal) async {
    isGenerating = true
    generationErrorMessage = nil
    defer { isGenerating = false }

    do {
      generatedRecipe = try await RecipeGenerationService.generateRecipe(
        kind: .timedMeal(time: selectedTime, meal: meal),
        profile: profiles.first,
        pantryItems: pantryItems
      )
    } catch is CancellationError {
      return
    } catch {
      generationErrorMessage = error.localizedDescription
    }
  }

  private func symbolName(for meal: DailyMeal) -> String {
    switch meal {
    case .lunch:
      return "sun.max.fill"
    case .dinner:
      return "moon.stars.fill"
    }
  }

  private func subtitle(for meal: DailyMeal) -> String {
    switch meal {
    case .lunch:
      return "Generate a lunch recipe"
    case .dinner:
      return "Generate a dinner recipe"
    }
  }
}
