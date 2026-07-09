# Fellows prototype

## Requirements
- Xcode 26.5 or later
- iOS 26.5 deployment target
- A physical Apple Intelligence-compatible device with Apple Intelligence enabled for on-device recipe generation

Fellows does not show demo recipes when Apple Intelligence is unavailable or when a generated result does not satisfy the saved restrictions. In those cases, the interface reports the issue and lets the user try again.

Recipe views are intentionally text-only. Fellows does not generate, download, or display recipe images.

## Implemented flow
1. The existing Welcome and setup screens are shown only until the first profile is saved.
2. The second setup page includes a Diet Style picker with Healthy, Omnivore, Carnivore, Vegetarian, and Vegan options.
3. `MainTabView` exposes Dashboard, Pantry, Cook, and Profile.
4. Dashboard uses the Fellows logo, the Single Day custom font, an animated tomato mascot, a profile-aware Today's Tip, and separate Lunch and Dinner recommendations.
5. Dashboard summary cards are interactive: Pantry opens the Pantry tab, Diet opens Profile, and Lunch or Dinner scrolls to the related meal section.
6. Pantry supports adding ingredients, deleting them by swipe or with the trailing minus button, and generating a tailored recipe.
7. Missing ingredients in a recipe can be added directly to Pantry with the trailing plus button. A confirmation alert appears after the item is saved.
8. Cook first asks for one of the four original setup ranges: 0–15, 15–30, 30–60, or 60+ minutes. A second screen then asks whether the recipe is for Lunch or Dinner before generation starts.
9. Profile edits the original setup data, including Diet Style, and stores an optional custom image selected with PhotosPicker.
10. All future generations read the current SwiftData profile, so saved profile changes apply dynamically.
11. The supplied Fellows artwork is configured as the application icon.

## Performance changes
- Dashboard tip, lunch, and dinner are generated in one structured Apple Intelligence request instead of three separate requests.
- Dashboard results are cached in memory for the current day and profile.
- Pantry changes update the Dashboard counter without automatically regenerating both daily meals.
- Safety regeneration is capped at one retry.
- Prompts cap pantry context at 40 sorted items and recipes at six preparation steps.
- Cook does not start the model until both time range and meal have been selected.
- No image-generation model or remote image service is used.

## Apple Intelligence behavior
`RecipeGenerationService` uses `SystemLanguageModel.default` and `LanguageModelSession`. Generated output is structured with `@Generable`. Diet style, allergies, intolerances, custom restrictions, poorly digested foods, available time, selected meal, and relevant pantry contents are included in recipe requests.

If validation finds a conflict, Fellows asks Apple Intelligence for a different recipe instead of showing a local fallback. After the single retry, the app displays an error rather than presenting a potentially incompatible recipe.

Generated food suggestions are not medical advice; users should always check product labels and follow their own professional guidance.
