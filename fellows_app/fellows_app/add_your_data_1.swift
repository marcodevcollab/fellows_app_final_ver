//
//  add_your_data_1.swift
//  fellows_app
//
//  Created by san-12 on 07/07/2026.
//

import SwiftUI
import SwiftData

enum Eta: String, CaseIterable, Identifiable {
    case firstCase, secondCase, thirdCase, lastCase
    var id: Self { self }

    var label: String {
        switch self {
            case .firstCase: return "18-25"
            case .secondCase: return "26-35"
            case .thirdCase: return "36-59"
            case .lastCase: return "60+"
        }
    }
}

enum lunchTime: String, CaseIterable, Identifiable {
    case firstCase, secondCase, thirdCase, lastCase
    var id: Self { self }

    var label: String {
        switch self {
            case .firstCase: return "around 0-15min"
            case .secondCase: return "around 15-30min"
            case .thirdCase: return "around 30-60min"
            case .lastCase: return "around 60+ min"
        }
    }
}

enum dinnerTime: String, CaseIterable, Identifiable {
    case firstCase, secondCase, thirdCase, lastCase
    var id: Self { self }

    var label: String {
        switch self {
            case .firstCase: return "around 0-15min"
            case .secondCase: return "around 15-30min"
            case .thirdCase: return "around 30-60min"
            case .lastCase: return "around 60+ min"
        }
    }
}

// MARK: - Diet style

enum DietStyle: String, CaseIterable, Identifiable {
    case healthy
    case omnivore
    case carnivore
    case vegetarian
    case vegan

    var id: Self { self }

    var label: String {
        switch self {
            case .healthy: return "Healthy"
            case .omnivore: return "Omnivore"
            case .carnivore: return "Carnivore"
            case .vegetarian: return "Vegetarian"
            case .vegan: return "Vegan"
        }
    }
}

// MARK: - Intolleranze note

enum Intolerance: String, CaseIterable, Identifiable {
    case lactose, gluten, nickel, fructose, sulfites, additives
    var id: Self { self }

    var label: String {
        switch self {
            case .lactose: return "Lattosio"
            case .gluten: return "Glutine"
            case .nickel: return "Nichel"
            case .fructose: return "Fruttosio"
            case .sulfites: return "Solfiti"
            case .additives: return "Additivi"
        }
    }
}

// MARK: - Modello Paese

struct Country: Identifiable, Hashable {
    let id: String        // codice ISO, es. "IT"
    let name: String      // nome localizzato, es. "Italia"

    var flag: String {
        let base: UInt32 = 127397
        var flagString = ""
        for scalar in id.unicodeScalars {
            if let flagScalar = UnicodeScalar(base + scalar.value) {
                flagString.unicodeScalars.append(flagScalar)
            }
        }
        return flagString
    }
}

// MARK: - Sorgente dati

enum CountryProvider {
    static func allCountries(locale: Locale = .current) -> [Country] {
        Locale.Region.isoRegions
            .filter { $0.subRegions.isEmpty }
            .compactMap { region -> Country? in
                guard let name = locale.localizedString(forRegionCode: region.identifier) else {
                    return nil
                }
                return Country(id: region.identifier, name: name)
            }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Vista selezione paese

struct CountryPickerView: View {

    @Binding var selectedCountry: Country?
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    private let countries = CountryProvider.allCountries()

    private var filteredCountries: [Country] {
        guard !searchText.isEmpty else { return countries }
        return countries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredCountries) { country in
                Button {
                    selectedCountry = country
                    dismiss()
                } label: {
                    HStack {
                        Text(country.flag)
                        Text(country.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedCountry == country {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Cerca nazione")
            .navigationTitle("Nazione")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Modello persistente (SwiftData)

@Model
final class UserProfile {
    var ageRaw: String
    var countryCode: String
    var countryName: String
    var lunchTimeRaw: String
    var dinnerTimeRaw: String
    // Default value enables lightweight migration for profiles created before this field existed.
    var dietStyleRaw: String = "healthy"

    // Intolleranze note (salvate come raw values dell'enum Intolerance)
    var intolerancesRaw: [String]
    // Intolleranze aggiunte manualmente dall'utente, non presenti nell'elenco
    var customIntolerances: [String]
    // Testo libero: alimenti che l'utente non digerisce bene
    var poorlyDigestedFoods: String
    var profileImageData: Data?

    init(
        age: Eta,
        country: Country,
        lunchTime: lunchTime,
        dinnerTime: dinnerTime,
        dietStyle: DietStyle = .healthy,
        intolerances: Set<Intolerance> = [],
        customIntolerances: [String] = [],
        poorlyDigestedFoods: String = "",
        profileImageData: Data? = nil
    ) {
        self.ageRaw = age.rawValue
        self.countryCode = country.id
        self.countryName = country.name
        self.lunchTimeRaw = lunchTime.rawValue
        self.dinnerTimeRaw = dinnerTime.rawValue
        self.dietStyleRaw = dietStyle.rawValue
        self.intolerancesRaw = intolerances.map(\.rawValue)
        self.customIntolerances = customIntolerances
        self.poorlyDigestedFoods = poorlyDigestedFoods
        self.profileImageData = profileImageData
    }

    // Computed properties per lavorare con i tipi "veri" invece che con le stringhe grezze

    var age: Eta {
        get { Eta(rawValue: ageRaw) ?? .firstCase }
        set { ageRaw = newValue.rawValue }
    }

    var country: Country {
        get { Country(id: countryCode, name: countryName) }
        set {
            countryCode = newValue.id
            countryName = newValue.name
        }
    }

    var lunch: lunchTime {
        get { lunchTime(rawValue: lunchTimeRaw) ?? .firstCase }
        set { lunchTimeRaw = newValue.rawValue }
    }

    var dinner: dinnerTime {
        get { dinnerTime(rawValue: dinnerTimeRaw) ?? .firstCase }
        set { dinnerTimeRaw = newValue.rawValue }
    }

    var dietStyle: DietStyle {
        get { DietStyle(rawValue: dietStyleRaw) ?? .healthy }
        set { dietStyleRaw = newValue.rawValue }
    }

    var intolerances: Set<Intolerance> {
        get { Set(intolerancesRaw.compactMap { Intolerance(rawValue: $0) }) }
        set { intolerancesRaw = newValue.map(\.rawValue) }
    }
}

// MARK: - Vista principale (page controller orizzontale)

struct add_your_data_1: View {

    var onOnboardingCompleted: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var profiles: [UserProfile]

    @State private var navigate: Bool = false
    @State private var currentPage: Int = 0
    @State private var saveErrorMessage: String?

    // Domande - pagina 1
    @State private var selectedAge: Eta = .firstCase
    @State private var selectedCountry: Country? = nil
    @State private var showCountryPicker = false
    @State private var luTime: lunchTime = .firstCase
    @State private var diTime: dinnerTime = .firstCase

    // Domande - pagina 2
    @State private var selectedDietStyle: DietStyle = .healthy
    @State private var selectedIntolerances: Set<Intolerance> = []
    @State private var customIntolerances: [String] = []
    @State private var newCustomIntolerance: String = ""
    @State private var poorlyDigestedFoods: String = ""

    var body: some View {
        ZStack {
            // Semantic system colors automatically adapt to Light and Dark Mode.
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    pageOneContent
                        .padding(.top, 24)
                        .padding(.bottom, 52)
                        .tag(0)

                    pageTwoContent
                        .padding(.top, 24)
                        .padding(.bottom, 52)
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .overlay(alignment: .bottom) {
                    setupPageIndicator
                        .padding(.bottom, 12)
                }
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.primary.opacity(0.10), lineWidth: 1)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .animation(.easeInOut, value: currentPage)

                // Il bottone vive FUORI dalla TabView: così non si sovrappone mai
                // ai puntini di paging, che restano confinati dentro la TabView.
                if currentPage == 1 {
                    saveButton
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .transition(.opacity)
                }
            }
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(selectedCountry: $selectedCountry)
        }
        .onAppear(perform: loadExistingProfile)
        .alert(
            "Unable to save your profile",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "Please try again.")
        }
        .navigationDestination(isPresented: $navigate) {
            // add_your_data_2()
        }
    }

    private var setupPageIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<2, id: \.self) { page in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentPage = page
                    }
                } label: {
                    Circle()
                        .fill(.white.opacity(currentPage == page ? 1 : 0.42))
                        .frame(width: currentPage == page ? 10 : 8, height: currentPage == page ? 10 : 8)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Setup page \(page + 1) of 2")
                .accessibilityAddTraits(currentPage == page ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Color.black.opacity(colorScheme == .dark ? 0.62 : 0.34),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(.white.opacity(colorScheme == .dark ? 0.22 : 0.38), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Pagina 1

    private var pageOneContent: some View {
        VStack {
            HStack {
                Image("tomato_drawn")
                    .resizable()
                    .frame(width: 250, height: 250)
                    .padding(.bottom, 0)
            }

            List {
                Button {
                    showCountryPicker = true
                } label: {
                    HStack {
                        Text("Where do you live?")
                            .foregroundStyle(.primary)
                        Spacer()
                        if let selectedCountry {
                            Text(selectedCountry.flag)
                            Text(selectedCountry.name)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Select")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Picker("What's your age?", selection: $selectedAge) {
                    ForEach(Eta.allCases) { eta in
                        Text(eta.label).tag(eta)
                    }
                }
                Picker("How much time do you have for lunch?", selection: $luTime) {
                    ForEach(lunchTime.allCases) { time in
                        Text(time.label).tag(time)
                    }
                }
                Picker("How much time do you have for dinner?", selection: $diTime) {
                    ForEach(dinnerTime.allCases) { time in
                        Text(time.label).tag(time)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }

    // MARK: - Pagina 2

    private var pageTwoContent: some View {
        List {
            Section {
                Picker("Diet style", selection: $selectedDietStyle) {
                    ForEach(DietStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
            } header: {
                Text("What is your diet style?")
            }

            Section {
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
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            } header: {
                Text("Do you have any intolerances?")
            }

            Section {
                ForEach(customIntolerances, id: \.self) { custom in
                    HStack {
                        Text(custom)
                        Spacer()
                        Button {
                            removeCustomIntolerance(custom)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onDelete { indexSet in
                    customIntolerances.remove(atOffsets: indexSet)
                }

                HStack {
                    TextField("Add another intolerance", text: $newCustomIntolerance)
                    Button {
                        addCustomIntolerance()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newCustomIntolerance.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Not in the list?")
            }

            Section {
                TextField(
                    "e.g. spicy food, fried food, mushrooms…",
                    text: $poorlyDigestedFoods,
                    axis: .vertical
                )
                .lineLimit(3...6)
            } header: {
                Text("Any foods you don't digest well?")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    // MARK: - Bottone Save (mostrato solo sulla pagina 2)

    private var saveButton: some View {
        Button {
            saveProfile()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.square")
                    .font(.system(size: 17))
                Text("save and continue")
                    .font(.custom("SingleDay-Regular", size: 24))
            }
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(width: 251, height: 67)
            .background(Color(red: 0.56, green: 0.75, blue: 0.51))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Azioni intolleranze

    private func toggle(_ intolerance: Intolerance) {
        if selectedIntolerances.contains(intolerance) {
            selectedIntolerances.remove(intolerance)
        } else {
            selectedIntolerances.insert(intolerance)
        }
    }

    private func addCustomIntolerance() {
        let trimmed = newCustomIntolerance.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !customIntolerances.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            newCustomIntolerance = ""
            return
        }
        customIntolerances.append(trimmed)
        newCustomIntolerance = ""
    }

    private func removeCustomIntolerance(_ intolerance: String) {
        customIntolerances.removeAll { $0 == intolerance }
    }

    // MARK: - Persistenza

    /// Se esiste già un profilo salvato (l'utente torna su questa schermata),
    /// ricarica i valori nei controlli invece di ripartire da zero.
    private func loadExistingProfile() {
        guard let existing = profiles.first else { return }
        selectedAge = existing.age
        selectedCountry = existing.country
        luTime = existing.lunch
        diTime = existing.dinner
        selectedDietStyle = existing.dietStyle
        selectedIntolerances = existing.intolerances
        customIntolerances = existing.customIntolerances
        poorlyDigestedFoods = existing.poorlyDigestedFoods
    }

    /// Crea un nuovo profilo o aggiorna quello esistente, poi salva nel database
    /// e passa alla schermata successiva.
    private func saveProfile() {
        guard let selectedCountry else {
            saveErrorMessage = "Please select your country before continuing."
            return
        }

        if let existing = profiles.first {
            existing.age = selectedAge
            existing.country = selectedCountry
            existing.lunch = luTime
            existing.dinner = diTime
            existing.dietStyle = selectedDietStyle
            existing.intolerances = selectedIntolerances
            existing.customIntolerances = customIntolerances
            existing.poorlyDigestedFoods = poorlyDigestedFoods
        } else {
            let newProfile = UserProfile(
                age: selectedAge,
                country: selectedCountry,
                lunchTime: luTime,
                dinnerTime: diTime,
                dietStyle: selectedDietStyle,
                intolerances: selectedIntolerances,
                customIntolerances: customIntolerances,
                poorlyDigestedFoods: poorlyDigestedFoods
            )
            modelContext.insert(newProfile)
        }

        do {
            try modelContext.save()
            onOnboardingCompleted()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        add_your_data_1()
    }
    .modelContainer(for: UserProfile.self, inMemory: true)
}
