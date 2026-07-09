import SwiftUI

enum AppTab: Hashable {
  case home
  case pantry
  case cook
  case profile
}

struct MainTabView: View {
  @State private var selectedTab: AppTab = .home

  var body: some View {
    TabView(selection: $selectedTab) {
      Tab("Home", systemImage: "house.fill", value: AppTab.home) {
        DashboardView(selectedTab: $selectedTab)
      }

      Tab("Pantry", systemImage: "cabinet.fill", value: AppTab.pantry) {
        PantryView()
      }

      Tab("Cook", systemImage: "frying.pan.fill", value: AppTab.cook) {
        CookView()
      }

      Tab("Profile", systemImage: "person.crop.circle.fill", value: AppTab.profile) {
        ProfileView()
      }
    }
    .tint(Color(red: 0.56, green: 0.75, blue: 0.51))
  }
}
