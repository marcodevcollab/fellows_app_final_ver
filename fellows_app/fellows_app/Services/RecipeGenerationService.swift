import Foundation
import FoundationModels

@MainActor
enum RecipeGenerationService {
  private static let model = SystemLanguageModel.default
  private static let maximumSafetyAttempts = 2
  private static var dailyPlanCache: [String: DailyPlanResult] = [:]

  private static let recipeInstructions = """
    You are the on-device recipe assistant inside Fellows.
    Create practical home-cooking recipes in English.
    The saved diet style, allergies, intolerances, and poorly digested foods are hard constraints.
    Restrictions are never a reason to refuse the request: always create a suitable recipe by choosing safe alternatives.
    Never include, recommend, or list an excluded ingredient, including as an optional garnish or missing ingredient.
    Do not repeat or name excluded foods in the generated recipe, even to say that the recipe is free from them.
    Do not claim to diagnose, treat, or cure a medical condition.
    Keep summaries and preparation steps concise to minimise processing time.
    Return realistic ingredient quantities and no more than six preparation steps.
    """

  static func generateRecipe(
    kind: RecipeRequestKind,
    profile: UserProfile?,
    pantryItems: [PantryItem]
  ) async throws -> RecipeResult {
    try ensureModelIsReady()

    let session = LanguageModelSession(instructions: recipeInstructions)
    let basePrompt = recipePrompt(kind: kind, profile: profile, pantryItems: pantryItems)
    var receivedModelResponse = false

    for attempt in 0..<maximumSafetyAttempts {
      try Task.checkCancellation()
      let retryInstruction =
        attempt == 0
        ? ""
        : """

        SAFETY RETRY
        Create a different recipe and verify every ingredient against all saved restrictions before responding.
        """

      do {
        let response = try await session.respond(
          to: basePrompt + retryInstruction,
          generating: GeneratedRecipe.self
        )
        receivedModelResponse = true

        let recipe = preparedRecipe(response.content)
        guard validates(recipe: recipe, profile: profile) else { continue }

        return RecipeResult(
          recipe: recipe,
          source: .appleIntelligence,
          statusMessage: nil
        )
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        // Missing model assets and similar infrastructure failures will not be
        // fixed by repeating the same request.
        throw mappedGenerationError(from: error)
      }
    }

    if receivedModelResponse {
      throw RecipeGenerationError.couldNotCreateCompliantRecipe
    }
    throw RecipeGenerationError.generationFailed
  }

  /// Generates the Dashboard tip, lunch, and dinner in one model request.
  /// This replaces three independent sessions and substantially reduces model
  /// startup, prompt, and safety-analysis overhead.
  static func generateDailyPlan(
    profile: UserProfile?,
    pantryItems: [PantryItem]
  ) async throws -> DailyPlanResult {
    let cacheKey = dailyPlanCacheKey(profile: profile)
    if let cached = dailyPlanCache[cacheKey] {
      return cached
    }

    try ensureModelIsReady()

    let session = LanguageModelSession(
      instructions: recipeInstructions + """

        Return one concise food-planning tip and two different recipes: lunch and dinner.
        The tip must be one sentence without a heading.
        """
    )
    let basePrompt = dailyPlanPrompt(profile: profile, pantryItems: pantryItems)
    var receivedModelResponse = false

    for attempt in 0..<maximumSafetyAttempts {
      try Task.checkCancellation()
      let retryInstruction =
        attempt == 0
        ? ""
        : """

        SAFETY RETRY
        Replace both meals with different recipes and verify the tip and every ingredient against all saved restrictions.
        """

      do {
        let response = try await session.respond(
          to: basePrompt + retryInstruction,
          generating: GeneratedDailyPlan.self
        )
        receivedModelResponse = true

        let tipText = cleanedTip(response.content.tip)
        let lunch = preparedRecipe(response.content.lunch)
        let dinner = preparedRecipe(response.content.dinner)

        guard
          !tipText.isEmpty,
          !textConflictsWithProfile(tipText, profile: profile),
          validates(recipe: lunch, profile: profile),
          validates(recipe: dinner, profile: profile)
        else {
          continue
        }

        let result = DailyPlanResult(
          tip: TipResult(text: tipText, source: .appleIntelligence),
          lunch: RecipeResult(recipe: lunch, source: .appleIntelligence, statusMessage: nil),
          dinner: RecipeResult(recipe: dinner, source: .appleIntelligence, statusMessage: nil)
        )
        dailyPlanCache[cacheKey] = result
        return result
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        throw mappedGenerationError(from: error)
      }
    }

    if receivedModelResponse {
      throw RecipeGenerationError.couldNotCreateCompliantRecipe
    }
    throw RecipeGenerationError.generationFailed
  }

  static func localTodayTip(profile: UserProfile?) -> TipResult {
    TipResult(text: fallbackTip(profile: profile), source: .localGuidance)
  }

  static var availabilityDescription: String {
    switch model.availability {
    case .available:
      return "Apple Intelligence is ready. Recipes are generated on device."
    case .unavailable(.deviceNotEligible):
      return "Apple Intelligence is not supported on this device."
    case .unavailable(.appleIntelligenceNotEnabled):
      return "Turn on Apple Intelligence in Settings to generate recipes."
    case .unavailable(.modelNotReady):
      return "The Apple Intelligence model is still preparing or downloading."
    case .unavailable:
      return "Apple Intelligence is currently unavailable."
    }
  }

  private static func ensureModelIsReady() throws {
    switch model.availability {
    case .available:
      return
    case .unavailable(.deviceNotEligible):
      throw RecipeGenerationError.deviceNotEligible
    case .unavailable(.appleIntelligenceNotEnabled):
      throw RecipeGenerationError.appleIntelligenceNotEnabled
    case .unavailable(.modelNotReady):
      throw RecipeGenerationError.modelNotReady
    case .unavailable:
      throw RecipeGenerationError.generationFailed
    }
  }

  private static func mappedGenerationError(from error: Error) -> RecipeGenerationError {
    if isMissingModelAssetError(error) {
      return .modelAssetsUnavailable
    }

    if let generationError = error as? LanguageModelSession.GenerationError {
      switch generationError {
      case .assetsUnavailable:
        return .modelAssetsUnavailable
      default:
        break
      }
    }

    return .generationFailed
  }

  /// Foundation Models can report an available primary language model while an
  /// auxiliary asset, such as the local safety sanitizer, is still absent.
  /// Those failures are frequently wrapped several levels deep in NSError.
  private static func isMissingModelAssetError(_ error: Error) -> Bool {
    var pendingErrors: [NSError] = [error as NSError]
    var visited = Set<ObjectIdentifier>()

    while let current = pendingErrors.popLast() {
      let identifier = ObjectIdentifier(current)
      guard visited.insert(identifier).inserted else { continue }

      let diagnostic = [
        current.domain,
        String(current.code),
        current.localizedDescription,
        current.localizedFailureReason ?? "",
        String(reflecting: current),
      ]
      .joined(separator: " ")
      .lowercased()

      let isSensitiveContentAssetFailure =
        current.domain == "com.apple.SensitiveContentAnalysisML" && current.code == 15
      let isUnifiedAssetFailure =
        current.domain == "com.apple.UnifiedAssetFramework" && current.code == 5000
      let containsKnownAssetMessage =
        diagnostic.contains("com.apple.fm.language.instruct_300m.safety")
        || diagnostic.contains("model catalog")
        || diagnostic.contains("underlying assets")
        || diagnostic.contains("assetsunavailable")
        || diagnostic.contains("local sanitizer asset")

      if isSensitiveContentAssetFailure || isUnifiedAssetFailure || containsKnownAssetMessage {
        return true
      }

      if let underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError {
        pendingErrors.append(underlying)
      }

      for value in current.userInfo.values {
        if let nested = value as? NSError {
          pendingErrors.append(nested)
        } else if let nestedErrors = value as? [NSError] {
          pendingErrors.append(contentsOf: nestedErrors)
        }
      }
    }

    return false
  }

  private static func preparedRecipe(_ generated: GeneratedRecipe) -> GeneratedRecipe {
    var recipe = generated
    recipe.summary = recipe.summary.trimmingCharacters(in: .whitespacesAndNewlines)
    recipe.instructions = Array(recipe.instructions.prefix(6))
    recipe.missingIngredients = Array(recipe.missingIngredients.prefix(3))
    recipe.safetyNote =
      "Generated from your current Fellows profile. Always check product labels and follow your own professional guidance for allergies or intolerances."
    return recipe
  }

  private static func cleanedTip(_ text: String) -> String {
    String(
      text
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\n", with: " ")
        .prefix(240)
    )
  }

  private static func recipePrompt(
    kind: RecipeRequestKind,
    profile: UserProfile?,
    pantryItems: [PantryItem]
  ) -> String {
    let pantryDescription = pantryDescription(for: pantryItems)

    let requestDescription: String
    switch kind {
    case .dailyMeal(let meal):
      let timeAvailable: String
      switch meal {
      case .lunch:
        timeAvailable = profile?.lunch.label ?? "a practical everyday cooking time"
      case .dinner:
        timeAvailable = profile?.dinner.label ?? "a practical everyday cooking time"
      }
      requestDescription =
        "Create today's \(meal.rawValue). It must fit within \(timeAvailable). Prefer pantry ingredients when suitable."

    case .pantry:
      requestDescription =
        "Create one recipe that uses as many saved pantry ingredients as reasonably possible. List no more than three compatible missing ingredients."

    case .timedMeal(let option, let meal):
      requestDescription =
        "Create one \(meal.rawValue) recipe for the selected available time. \(option.promptConstraint) Make it appropriate for \(meal.rawValue) and prefer pantry ingredients when suitable."
    }

    return """
      REQUEST
      \(requestDescription)

      USER PROFILE
      \(profileDescription(profile))

      PANTRY
      \(pantryDescription)

      HARD REQUIREMENTS
      \(hardRequirements)
      """
  }

  private static func dailyPlanPrompt(
    profile: UserProfile?,
    pantryItems: [PantryItem]
  ) -> String {
    let lunchTime = profile?.lunch.label ?? "a practical everyday cooking time"
    let dinnerTime = profile?.dinner.label ?? "a practical everyday cooking time"

    return """
      CREATE TODAY'S FELLOWS PLAN
      - One short food-planning tip compatible with the profile.
      - One lunch that fits within \(lunchTime).
      - One different dinner that fits within \(dinnerTime).
      - Prefer saved pantry ingredients where appropriate.

      USER PROFILE
      \(profileDescription(profile))

      PANTRY
      \(pantryDescription(for: pantryItems))

      HARD REQUIREMENTS FOR BOTH RECIPES
      \(hardRequirements)
      """
  }

  private static var hardRequirements: String {
    """
      - Follow the diet style exactly.
      - Never include any saved intolerance, allergy, custom restriction, or poorly digested food.
      - Restrictions are hard filters; create a compatible alternative instead of refusing.
      - Do not name excluded foods anywhere in the title, summary, ingredients, missing ingredients, method, or tip.
      - Treat lactose intolerance as strictly dairy-free.
      - Treat gluten intolerance as strictly gluten-free and do not make cross-contamination claims.
      - Keep each recipe feasible for a home cook.
      - Include quantities in the ingredients.
      - Provide 3 to 6 concise preparation steps.
      - Return no more than three compatible missing ingredients as short pantry item names without quantities.
      - If the pantry is empty, still create suitable recipes from the profile.
      """
  }

  /// Limits very large pantry prompts while keeping deterministic ordering.
  private static func pantryDescription(for pantryItems: [PantryItem]) -> String {
    let pantry = pantryItems
      .map(\.name)
      .sorted()
      .prefix(40)
      .joined(separator: ", ")
    return pantry.isEmpty ? "No pantry ingredients have been saved." : pantry
  }

  private static func dailyPlanCacheKey(profile: UserProfile?) -> String {
    let day = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
    guard let profile else { return "no-profile#\(day)" }

    let profilePart = [
      profile.ageRaw,
      profile.countryCode,
      profile.dietStyleRaw,
      profile.lunchTimeRaw,
      profile.dinnerTimeRaw,
      profile.intolerancesRaw.sorted().joined(separator: ","),
      profile.customIntolerances.sorted().joined(separator: ","),
      profile.poorlyDigestedFoods,
    ].joined(separator: "|")

    return "\(profilePart)#\(day)"
  }

  private static func profileDescription(_ profile: UserProfile?) -> String {
    guard let profile else {
      return
        "No profile is available. Use a generally balanced omnivore recipe and clearly state common allergens."
    }

    let known = profile.intolerances
      .map(\.promptDescription)
      .sorted()
      .joined(separator: ", ")
    let custom = profile.customIntolerances.joined(separator: ", ")
    let poorlyDigested = profile.poorlyDigestedFoods.trimmingCharacters(in: .whitespacesAndNewlines)

    return """
      Age range: \(profile.age.label)
      Country: \(profile.countryName)
      Diet style: \(profile.dietStyle.promptDescription)
      Usual lunch time available: \(profile.lunch.label)
      Usual dinner time available: \(profile.dinner.label)
      Known intolerances: \(known.isEmpty ? "none saved" : known)
      Other intolerances or allergies: \(custom.isEmpty ? "none saved" : custom)
      Foods not digested well: \(poorlyDigested.isEmpty ? "none saved" : poorlyDigested)
      """
  }

  private static func validates(recipe: GeneratedRecipe, profile: UserProfile?) -> Bool {
    guard let profile else { return true }

    let contentToCheck = recipe.ingredients + recipe.missingIngredients + recipe.instructions
      + [recipe.title, recipe.summary]
    return !bannedTerms(for: profile).contains { bannedTerm in
      contentToCheck.contains { containsTerm(bannedTerm, in: $0) }
    }
  }

  private static func textConflictsWithProfile(_ text: String, profile: UserProfile?) -> Bool {
    guard let profile else { return false }
    return bannedTerms(for: profile).contains { containsTerm($0, in: text) }
  }

  private static func bannedTerms(for profile: UserProfile) -> Set<String> {
    var terms = Set<String>()

    for intolerance in profile.intolerances {
      terms.formUnion(intolerance.validationTerms)
    }
    terms.formUnion(profile.dietStyle.validationTerms)

    let customTerms =
      profile.customIntolerances
      + profile.poorlyDigestedFoods
      .split(whereSeparator: { ",;\n".contains($0) })
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

    for term in customTerms where term.count >= 3 {
      terms.insert(normalized(term))
    }
    return terms
  }

  private static func containsTerm(_ term: String, in text: String) -> Bool {
    let normalizedText = " " + normalizedWords(text) + " "
    let normalizedTerm = normalizedWords(term)
    guard !normalizedTerm.isEmpty else { return false }

    if normalizedText.contains(" " + normalizedTerm + " ") {
      return true
    }

    guard !normalizedTerm.contains(" ") else { return false }
    return normalizedText.contains(" " + normalizedTerm + "s ")
      || normalizedText.contains(" " + normalizedTerm + "es ")
  }

  private static func normalizedWords(_ text: String) -> String {
    normalized(text)
      .unicodeScalars
      .map { CharacterSet.alphanumerics.contains($0) ? Character(String($0)) : " " }
      .reduce(into: "") { $0.append($1) }
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
  }

  private static func normalized(_ text: String) -> String {
    text
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
      .lowercased()
  }

  private static func fallbackTip(profile: UserProfile?) -> String {
    guard let profile else {
      return
        "Plan one meal around ingredients you already have before adding anything new to your shopping list."
    }

    switch profile.dietStyle {
    case .healthy:
      return
        "Build today's meals around a variety of minimally processed ingredients you already have."
    case .omnivore:
      return "Balance your plate with vegetables, a protein source, and a satisfying carbohydrate."
    case .carnivore:
      return "Plan portions before cooking so you prepare only what you expect to eat today."
    case .vegetarian:
      return
        "Combine varied vegetarian protein sources across the day while respecting your saved restrictions."
    case .vegan:
      return
        "Use a variety of plant protein sources across the day while respecting your saved restrictions."
    }
  }
}

extension DietStyle {
  fileprivate var promptDescription: String {
    switch self {
    case .healthy:
      "Healthy — balanced, varied, and based mainly on minimally processed foods"
    case .omnivore:
      "Omnivore — may include both plant and animal foods"
    case .carnivore:
      "Carnivore — use animal-based foods only; do not include vegetables, fruit, grains, legumes, nuts, or seeds"
    case .vegetarian:
      "Vegetarian — no meat, poultry, fish, shellfish, animal stock, or gelatin; eggs and dairy are allowed only when compatible with saved restrictions"
    case .vegan:
      "Vegan — no meat, fish, shellfish, dairy, eggs, honey, gelatin, or any other animal-derived ingredient"
    }
  }

  fileprivate var validationTerms: Set<String> {
    let meatAndFish: Set<String> = [
      "beef", "veal", "pork", "ham", "bacon", "chicken", "turkey", "duck", "lamb", "mutton",
      "rabbit", "venison", "sausage", "salami", "prosciutto", "fish", "salmon", "tuna", "cod",
      "anchovy", "sardine", "shrimp", "prawn", "crab", "lobster", "mussel", "clam", "oyster",
      "shellfish", "gelatin", "gelatine", "meat stock", "chicken stock", "fish sauce",
    ]

    switch self {
    case .healthy, .omnivore:
      return []
    case .vegetarian:
      return meatAndFish
    case .vegan:
      return meatAndFish.union([
        "milk", "cream", "butter", "cheese", "yogurt", "yoghurt", "whey", "casein", "lactose",
        "parmesan", "mozzarella", "ricotta", "mascarpone", "egg", "eggs", "honey", "ghee",
      ])
    case .carnivore:
      return [
        "rice", "pasta", "bread", "flour", "oat", "barley", "wheat", "rye", "quinoa", "corn",
        "potato", "tomato", "pepper", "onion", "garlic", "carrot", "zucchini", "courgette",
        "aubergine", "eggplant", "broccoli", "spinach", "lettuce", "cabbage", "mushroom", "bean",
        "lentil", "chickpea", "pea", "soy", "tofu", "tempeh", "fruit", "apple", "banana",
        "orange", "lemon", "lime", "berry", "avocado", "olive oil", "coconut", "almond", "walnut",
        "hazelnut", "peanut", "cashew", "seed", "herb", "parsley", "basil",
      ]
    }
  }
}

extension Intolerance {
  fileprivate var promptDescription: String {
    switch self {
    case .lactose: "lactose intolerance — strictly dairy-free"
    case .gluten: "gluten intolerance — strictly gluten-free"
    case .nickel: "nickel intolerance"
    case .fructose: "fructose intolerance"
    case .sulfites: "sulfite intolerance"
    case .additives: "sensitivity to food additives"
    }
  }

  fileprivate var validationTerms: Set<String> {
    switch self {
    case .lactose:
      [
        "milk", "cream", "butter", "cheese", "yogurt", "yoghurt", "whey", "casein", "lactose",
        "parmesan", "mozzarella", "ricotta", "mascarpone", "ghee",
      ]
    case .gluten:
      [
        "wheat", "barley", "rye", "spelt", "flour", "bread", "pasta", "couscous", "bulgur",
        "seitan", "soy sauce",
      ]
    case .nickel:
      ["cocoa", "chocolate", "hazelnut", "almond", "peanut", "soy", "lentil", "chickpea", "oats"]
    case .fructose:
      ["honey", "agave", "apple", "pear", "mango", "watermelon", "high-fructose", "dried fruit"]
    case .sulfites:
      ["sulfite", "sulphite", "wine", "dried fruit", "bottled lemon juice"]
    case .additives:
      ["stock cube", "flavor enhancer", "colouring", "coloring", "preservative", "processed sauce"]
    }
  }
}
