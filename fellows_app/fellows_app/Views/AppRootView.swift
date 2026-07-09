import SwiftData
import SwiftUI

struct AppRootView: View {
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Query private var profiles: [UserProfile]

  var body: some View {
    ZStack {
      if hasCompletedOnboarding {
        MainTabView()
          .transition(
            .asymmetric(
              insertion: .move(edge: .trailing).combined(with: .opacity),
              removal: .move(edge: .trailing).combined(with: .opacity)
            )
          )
      } else {
        ContentView(onOnboardingCompleted: completeOnboarding)
          .transition(
            .asymmetric(
              insertion: .move(edge: .leading).combined(with: .opacity),
              removal: .move(edge: .leading).combined(with: .opacity)
            )
          )
      }
    }
    // Do not clip the root container: the native iOS tab bar draws part of its
    // Liquid Glass border and shadow outside its layout bounds.
    // A nil preference leaves the appearance under iOS control, so Fellows
    // automatically follows the user's Light/Dark Mode setting.
    .preferredColorScheme(nil)
    .onAppear {
      // Keeps existing installations out of onboarding if a profile was
      // already saved before the completion flag was introduced.
      if !profiles.isEmpty && !hasCompletedOnboarding {
        hasCompletedOnboarding = true
      }
    }
  }

  private func completeOnboarding() {
    if reduceMotion {
      hasCompletedOnboarding = true
    } else {
      withAnimation(.smooth(duration: 0.58)) {
        hasCompletedOnboarding = true
      }
    }
  }
}
