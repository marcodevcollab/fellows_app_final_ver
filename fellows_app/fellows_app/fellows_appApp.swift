//
//  fellows_appApp.swift
//  fellows_app
//
//  Created by san-12 on 02/07/2026.
//

import SwiftData
import SwiftUI

@main
struct FellowsApp: App {
  var body: some Scene {
    WindowGroup {
      AppRootView()
    }
    .modelContainer(for: [UserProfile.self, PantryItem.self])
  }
}
