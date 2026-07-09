import Foundation
import FoundationModels

@Generable
struct GeneratedRecipe {
  var title: String
  var summary: String
  var preparationTime: String
  var servings: String
  var ingredients: [String]
  var instructions: [String]
  var missingIngredients: [String]
  var safetyNote: String
}

@Generable
struct GeneratedDailyPlan {
  var tip: String
  var lunch: GeneratedRecipe
  var dinner: GeneratedRecipe
}

enum RecipeGenerationSource: String {
  case appleIntelligence = "Apple Intelligence"
  case localGuidance = "Fellows guidance"
}

struct RecipeResult: Identifiable {
  let id = UUID()
  let recipe: GeneratedRecipe
  let source: RecipeGenerationSource
  let statusMessage: String?
}

struct TipResult {
  let text: String
  let source: RecipeGenerationSource
}

struct DailyPlanResult {
  let tip: TipResult
  let lunch: RecipeResult
  let dinner: RecipeResult
}

enum RecipeGenerationError: LocalizedError {
  case deviceNotEligible
  case appleIntelligenceNotEnabled
  case modelNotReady
  case modelAssetsUnavailable
  case couldNotCreateCompliantRecipe
  case generationFailed

  var errorDescription: String? {
    switch self {
    case .deviceNotEligible:
      return "Apple Intelligence is not supported on this device."
    case .appleIntelligenceNotEnabled:
      return "Turn on Apple Intelligence in Settings to generate recipes."
    case .modelNotReady:
      return "The Apple Intelligence model is still preparing or downloading. Try again later."
    case .modelAssetsUnavailable:
      return "The Apple Intelligence language or safety model files are unavailable. On Simulator, try a current runtime or run Fellows on a compatible physical iPhone with Apple Intelligence enabled and fully downloaded."
    case .couldNotCreateCompliantRecipe:
      return "Fellows could not create a recipe that safely matches all the restrictions in your profile. Review your preferences and try again."
    case .generationFailed:
      return "Apple Intelligence could not complete the recipe. Please try again."
    }
  }
}

enum DailyMeal: String, Identifiable, Equatable {
  case lunch
  case dinner

  var id: String { rawValue }

  var title: String {
    switch self {
    case .lunch: "Lunch"
    case .dinner: "Dinner"
    }
  }
}

enum RecipeRequestKind {
  case dailyMeal(DailyMeal)
  case pantry
  case timedMeal(time: CookingTimeOption, meal: DailyMeal)
}

enum CookingTimeOption: String, CaseIterable, Hashable, Identifiable {
  case zeroToFifteen = "around 0-15min"
  case fifteenToThirty = "around 15-30min"
  case thirtyToSixty = "around 30-60min"
  case sixtyPlus = "around 60+ min"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .zeroToFifteen: "0–15 min"
    case .fifteenToThirty: "15–30 min"
    case .thirtyToSixty: "30–60 min"
    case .sixtyPlus: "60+ min"
    }
  }

  var subtitle: String {
    switch self {
    case .zeroToFifteen: "Something very quick"
    case .fifteenToThirty: "A fast everyday meal"
    case .thirtyToSixty: "Time for a complete recipe"
    case .sixtyPlus: "Cook without rushing"
    }
  }

  var promptConstraint: String {
    switch self {
    case .zeroToFifteen: "The complete recipe must take no more than 15 minutes."
    case .fifteenToThirty: "The complete recipe must take between 15 and 30 minutes."
    case .thirtyToSixty: "The complete recipe must take between 30 and 60 minutes."
    case .sixtyPlus: "The recipe may take more than 60 minutes."
    }
  }

  var symbolName: String {
    switch self {
    case .zeroToFifteen: "bolt.fill"
    case .fifteenToThirty: "timer"
    case .thirtyToSixty: "clock.fill"
    case .sixtyPlus: "hourglass"
    }
  }
}
