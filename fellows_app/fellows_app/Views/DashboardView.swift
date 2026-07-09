import SwiftData
import SwiftUI

struct DashboardView: View {
  @Binding var selectedTab: AppTab

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Query private var profiles: [UserProfile]
  @Query(sort: \PantryItem.createdAt) private var pantryItems: [PantryItem]

  @State private var lunchResult: RecipeResult?
  @State private var dinnerResult: RecipeResult?
  @State private var lunchErrorMessage: String?
  @State private var dinnerErrorMessage: String?
  @State private var tipResult: TipResult?
  @State private var isLoading = false
  @State private var mascotHasAppeared = false

  private var profile: UserProfile? { profiles.first }

  private var generationKey: String {
    let profilePart =
      profile.map {
        [
          $0.ageRaw,
          $0.countryCode,
          $0.dietStyleRaw,
          $0.lunchTimeRaw,
          $0.dinnerTimeRaw,
          $0.intolerancesRaw.sorted().joined(separator: ","),
          $0.customIntolerances.sorted().joined(separator: ","),
          $0.poorlyDigestedFoods,
        ].joined(separator: "|")
      } ?? "no-profile"
    // Pantry changes update the summary immediately but do not force an
    // expensive re-generation of both daily meals. Pantry-specific recipes are
    // generated on demand from the Pantry and Cook tabs.
    let day = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
    return "\(profilePart)#\(day)"
  }

  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            header
            summaryGrid(scrollProxy: proxy)
            todayTip
            todaysMeals
          }
          .padding()
        }
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Image("logo_fellows")
            .resizable()
            .scaledToFill()
            .frame(width: 142, height: 34)
            .clipped()
            .accessibilityLabel("Fellows")
        }
      }
      .task(id: generationKey) {
        await loadDailyContent()
      }
      .onAppear {
        if reduceMotion {
          mascotHasAppeared = true
        } else {
          withAnimation(.smooth(duration: 0.7)) {
            mascotHasAppeared = true
          }
        }
      }
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 5) {
        Text("\(greeting),")
          .font(.custom("SingleDay-Regular", size: 38))
        Text("here is your food overview for today.")
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 4)

      VStack(spacing: 0) {
        Text("Let's cook!")
          .font(.custom("SingleDay-Regular", size: 18))
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(.thinMaterial, in: Capsule())

        Image("tomato_drawn")
          .resizable()
          .scaledToFit()
          .frame(width: 104, height: 104)
          .offset(x: mascotHasAppeared ? 0 : 160)
          .opacity(mascotHasAppeared ? 1 : 0)
          .accessibilityLabel("Fellows tomato mascot waving")
      }
    }
  }

  private func summaryGrid(scrollProxy: ScrollViewProxy) -> some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
      summaryItem(
        title: "Pantry",
        value: "\(pantryItems.count) items",
        icon: "cabinet.fill",
        accessibilityHint: "Opens the Pantry tab"
      ) {
        selectedTab = .pantry
      }

      summaryItem(
        title: "Diet",
        value: profile?.dietStyle.label ?? "Not set",
        icon: "leaf.circle.fill",
        accessibilityHint: "Opens your profile"
      ) {
        selectedTab = .profile
      }

      summaryItem(
        title: "Lunch",
        value: profile?.lunch.label ?? "Not set",
        icon: "sun.max.fill",
        accessibilityHint: "Scrolls to today's lunch"
      ) {
        withAnimation(.snappy) {
          scrollProxy.scrollTo(DashboardSection.lunch, anchor: .top)
        }
      }

      summaryItem(
        title: "Dinner",
        value: profile?.dinner.label ?? "Not set",
        icon: "moon.stars.fill",
        accessibilityHint: "Scrolls to today's dinner"
      ) {
        withAnimation(.snappy) {
          scrollProxy.scrollTo(DashboardSection.dinner, anchor: .top)
        }
      }
    }
  }

  private func summaryItem(
    title: String,
    value: String,
    icon: String,
    accessibilityHint: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      FellowsCard {
        VStack(alignment: .leading, spacing: 10) {
          Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(.tint)
          Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(value)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityHint(accessibilityHint)
  }

  private var todayTip: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Today's Tip")
        .font(.custom("SingleDay-Regular", size: 30))

      FellowsCard {
        HStack(alignment: .top, spacing: 14) {
          Image(systemName: "lightbulb.max.fill")
            .font(.title2)
            .foregroundStyle(.yellow)
          if let tipResult {
            VStack(alignment: .leading, spacing: 6) {
              Text(tipResult.text)
              Text(tipResult.source.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          } else {
            ProgressView()
          }
        }
      }
    }
  }

  private var todaysMeals: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Today's Meals")
        .font(.custom("SingleDay-Regular", size: 30))

      mealSection(
        meal: .lunch,
        result: lunchResult,
        errorMessage: lunchErrorMessage
      )
      .id(DashboardSection.lunch)

      mealSection(
        meal: .dinner,
        result: dinnerResult,
        errorMessage: dinnerErrorMessage
      )
      .id(DashboardSection.dinner)
    }
  }

  @ViewBuilder
  private func mealSection(
    meal: DailyMeal,
    result: RecipeResult?,
    errorMessage: String?
  ) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      Label(meal.title, systemImage: meal == .lunch ? "sun.max.fill" : "moon.stars.fill")
        .font(.custom("SingleDay-Regular", size: 24))
        .foregroundStyle(.primary)

      if let result {
        NavigationLink {
          RecipeDetailView(result: result)
        } label: {
          RecipePreviewCard(result: result)
        }
        .buttonStyle(.plain)
      } else if let errorMessage {
        FellowsCard {
          VStack(alignment: .leading, spacing: 12) {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
              .font(.subheadline)
            Button("Try Again", systemImage: "arrow.clockwise") {
              Task { await loadDailyContent() }
            }
            .buttonStyle(.bordered)
          }
        }
      } else if isLoading {
        FellowsCard {
          HStack(spacing: 12) {
            ProgressView()
            Text("Creating today's \(meal.rawValue)…")
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private var greeting: String {
    let hour = Calendar.current.component(.hour, from: .now)

    switch hour {
    case 5..<12:
      return "Good morning"
    case 12..<18:
      return "Good afternoon"
    default:
      return "Good evening"
    }
  }

  private func loadDailyContent() async {
    isLoading = true
    lunchResult = nil
    dinnerResult = nil
    lunchErrorMessage = nil
    dinnerErrorMessage = nil

    // Show useful local guidance immediately while one single Apple Intelligence
    // request creates the tip, lunch, and dinner together.
    tipResult = RecipeGenerationService.localTodayTip(profile: profile)

    do {
      let plan = try await RecipeGenerationService.generateDailyPlan(
        profile: profile,
        pantryItems: pantryItems
      )
      tipResult = plan.tip
      lunchResult = plan.lunch
      dinnerResult = plan.dinner
    } catch is CancellationError {
      isLoading = false
      return
    } catch {
      let message = error.localizedDescription
      lunchErrorMessage = message
      dinnerErrorMessage = message
    }

    isLoading = false
  }
}

private enum DashboardSection: Hashable {
  case lunch
  case dinner
}
