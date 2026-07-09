import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct ProfileView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var profiles: [UserProfile]

  @State private var selectedAge: Eta = .firstCase
  @State private var selectedCountry: Country?
  @State private var lunchSelection: lunchTime = .firstCase
  @State private var dinnerSelection: dinnerTime = .firstCase
  @State private var selectedDietStyle: DietStyle = .healthy
  @State private var selectedIntolerances: Set<Intolerance> = []
  @State private var customIntolerances: [String] = []
  @State private var newCustomIntolerance = ""
  @State private var poorlyDigestedFoods = ""
  @State private var profileImageData: Data?
  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var showCountryPicker = false
  @State private var showSavedConfirmation = false

  private var profile: UserProfile? { profiles.first }

  var body: some View {
    NavigationStack {
      Group {
        if profile == nil {
          ContentUnavailableView(
            "Profile unavailable", systemImage: "person.crop.circle.badge.exclamationmark")
        } else {
          Form {
            photoSection
            detailsSection
            dietSection
            timingSection
            intoleranceSection
            digestionSection
          }
        }
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("Profile")
            .font(.custom("SingleDay-Regular", size: 28))
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: saveProfile)
            .disabled(profile == nil)
        }
      }
      .sheet(isPresented: $showCountryPicker) {
        CountryPickerView(selectedCountry: $selectedCountry)
      }
      .alert("Profile updated", isPresented: $showSavedConfirmation) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Future recipes and tips will use your updated preferences.")
      }
      .onAppear(perform: loadProfile)
      .onChange(of: profiles.count) { _, _ in loadProfile() }
      .onChange(of: selectedPhotoItem) { _, item in
        guard let item else { return }
        Task { await loadPhoto(from: item) }
      }
    }
  }

  private var photoSection: some View {
    Section {
      HStack {
        Spacer()
        VStack(spacing: 12) {
          profileImage
          PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Label("Choose Photo", systemImage: "photo.on.rectangle")
          }
          .buttonStyle(.bordered)
        }
        Spacer()
      }
      .listRowBackground(Color.clear)
    }
  }

  @ViewBuilder
  private var profileImage: some View {
    if let profileImageData, let image = UIImage(data: profileImageData) {
      Image(uiImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: 112, height: 112)
        .clipShape(Circle())
        .overlay(Circle().stroke(.quaternary, lineWidth: 1))
        .accessibilityLabel("Profile photo")
    } else {
      Image(systemName: "person.crop.circle.fill")
        .resizable()
        .scaledToFit()
        .frame(width: 112, height: 112)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Default profile image")
    }
  }

  private var detailsSection: some View {
    Section("Personal information") {
      Picker("Age", selection: $selectedAge) {
        ForEach(Eta.allCases) { age in
          Text(age.label).tag(age)
        }
      }

      Button {
        showCountryPicker = true
      } label: {
        HStack {
          Text("Country")
            .foregroundStyle(.primary)
          Spacer()
          if let selectedCountry {
            Text("\(selectedCountry.flag) \(selectedCountry.name)")
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private var dietSection: some View {
    Section("Diet style") {
      Picker("Diet style", selection: $selectedDietStyle) {
        ForEach(DietStyle.allCases) { style in
          Text(style.label).tag(style)
        }
      }
    }
  }

  private var timingSection: some View {
    Section("Usual cooking time") {
      Picker("Lunch", selection: $lunchSelection) {
        ForEach(lunchTime.allCases) { time in
          Text(time.label).tag(time)
        }
      }
      Picker("Dinner", selection: $dinnerSelection) {
        ForEach(dinnerTime.allCases) { time in
          Text(time.label).tag(time)
        }
      }
    }
  }

  private var intoleranceSection: some View {
    Section("Intolerances and allergies") {
      ForEach(Intolerance.allCases) { intolerance in
        Button {
          toggle(intolerance)
        } label: {
          HStack {
            Text(intolerance.label)
              .foregroundStyle(.primary)
            Spacer()
            if selectedIntolerances.contains(intolerance) {
              Image(systemName: "checkmark")
            }
          }
        }
      }

      ForEach(customIntolerances, id: \.self) { item in
        HStack {
          Text(item)
          Spacer()
          Button("Remove", systemImage: "minus.circle.fill") {
            customIntolerances.removeAll { $0 == item }
          }
          .labelStyle(.iconOnly)
          .foregroundStyle(.secondary)
        }
      }
      .onDelete { customIntolerances.remove(atOffsets: $0) }

      HStack {
        TextField("Add another", text: $newCustomIntolerance)
        Button("Add", systemImage: "plus.circle.fill", action: addCustomIntolerance)
          .labelStyle(.iconOnly)
          .disabled(newCustomIntolerance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
  }

  private var digestionSection: some View {
    Section("Foods you don't digest well") {
      TextField(
        "e.g. spicy food, fried food, mushrooms…",
        text: $poorlyDigestedFoods,
        axis: .vertical
      )
      .lineLimit(3...6)
    }
  }

  private func loadProfile() {
    guard let profile else { return }
    selectedAge = profile.age
    selectedCountry = profile.country
    lunchSelection = profile.lunch
    dinnerSelection = profile.dinner
    selectedDietStyle = profile.dietStyle
    selectedIntolerances = profile.intolerances
    customIntolerances = profile.customIntolerances
    poorlyDigestedFoods = profile.poorlyDigestedFoods
    profileImageData = profile.profileImageData
  }

  private func saveProfile() {
    guard let profile, let selectedCountry else { return }
    profile.age = selectedAge
    profile.country = selectedCountry
    profile.lunch = lunchSelection
    profile.dinner = dinnerSelection
    profile.dietStyle = selectedDietStyle
    profile.intolerances = selectedIntolerances
    profile.customIntolerances = customIntolerances
    profile.poorlyDigestedFoods = poorlyDigestedFoods.trimmingCharacters(
      in: .whitespacesAndNewlines)
    profile.profileImageData = profileImageData
    try? modelContext.save()
    showSavedConfirmation = true
  }

  private func toggle(_ intolerance: Intolerance) {
    if selectedIntolerances.contains(intolerance) {
      selectedIntolerances.remove(intolerance)
    } else {
      selectedIntolerances.insert(intolerance)
    }
  }

  private func addCustomIntolerance() {
    let trimmed = newCustomIntolerance.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard
      !customIntolerances.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
    else {
      newCustomIntolerance = ""
      return
    }
    customIntolerances.append(trimmed)
    newCustomIntolerance = ""
  }

  private func loadPhoto(from item: PhotosPickerItem) async {
    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
    profileImageData = resizedJPEGData(from: data)
  }

  private func resizedJPEGData(from data: Data) -> Data? {
    guard let image = UIImage(data: data) else { return nil }
    let maximumDimension: CGFloat = 1_024
    let scale = min(1, maximumDimension / max(image.size.width, image.size.height))
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: size)
    let resized = renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
    return resized.jpegData(compressionQuality: 0.82)
  }
}
