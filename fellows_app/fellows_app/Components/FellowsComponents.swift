import SwiftUI

struct FellowsCard<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    content
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}

struct RecipePreviewCard: View {
  let result: RecipeResult

  var body: some View {
    FellowsCard {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .top) {
          Image(systemName: "fork.knife")
            .font(.title2)
            .foregroundStyle(.tint)
          Spacer()
          Label(result.recipe.preparationTime, systemImage: "clock")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Text(result.recipe.title)
          .font(.custom("SingleDay-Regular", size: 25))
        Text(result.recipe.summary)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(3)

        HStack {
          Text(result.source.rawValue)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
      }
    }
  }
}

struct PrimaryActionButtonLabel: View {
  let title: String
  let systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.headline)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
  }
}
