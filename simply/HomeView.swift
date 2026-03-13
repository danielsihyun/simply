import SwiftUI
import Combine

// MARK: - Date Nav Action Holder (reference type — prevents SwiftUI re-renders)
class DateNavAction {
    var selectedDate = Date()
    var onNavigate: ((Date, Edge) -> Void) = { _, _ in }

    func goBack() {
        let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        onNavigate(newDate, .trailing)
    }

    func goForward() {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        guard !cal.isDate(selectedDate, inSameDayAs: tomorrow) else { return }
        let newDate = cal.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        onNavigate(newDate, .leading)
    }
}

// MARK: - Date Navigation Buttons (native Liquid Glass)
struct DateNavButtons: View {
    let actions: DateNavAction
    @Namespace private var ns

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                Button { actions.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 24, height: 30)
                }
                .buttonStyle(.glass)
                .glassEffectUnion(id: "dateNav", namespace: ns)

                Button { actions.goForward() } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 24, height: 30)
                }
                .buttonStyle(.glass)
                .glassEffectUnion(id: "dateNav", namespace: ns)
            }
        }
    }
}

// MARK: - Settings Button (standalone Liquid Glass)
struct SettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.glass)
    }
}


// MARK: - Main View
struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var logService = LogService()
    @StateObject private var foodService = FoodService()

    @State private var inputText = ""
    @State private var mode: InputMode = .search
    @State private var pendingFood: Food?
    @State private var lastWasEnter = false
    @State private var currentMealIndex = 0
    @State private var suppressUndo = false
    @State private var selectedDate = Date()
    @State private var slideDirection: Edge = .trailing
    @State private var dateNavAction = DateNavAction()
    @State private var showSettings = false
    @State private var customFoodName = ""
    @State private var customStep: CustomStep = .serving
    @State private var customServing: Float = 100
    @State private var customCals: Float = 0
    @State private var customProtein: Float = 0
    @State private var customCarbs: Float = 0
    @FocusState private var inputFocused: Bool
    @FocusState private var gramsFocused: Bool

    enum InputMode { case search, grams, custom }

    enum CustomStep: Int, CaseIterable {
        case serving, calories, protein, carbs, fat

        var prompt: String {
            switch self {
            case .serving: return "serving size in grams"
            case .calories: return "calories per serving"
            case .protein: return "protein (g)"
            case .carbs: return "carbs (g)"
            case .fat: return "fat (g)"
            }
        }

        var label: String {
            switch self {
            case .serving: return "Serving"
            case .calories: return "Cal"
            case .protein: return "Protein"
            case .carbs: return "Carbs"
            case .fat: return "Fat"
            }
        }

        var next: CustomStep? {
            CustomStep(rawValue: rawValue + 1)
        }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var isTomorrow: Bool {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        return cal.isDate(selectedDate, inSameDayAs: tomorrow)
    }

    private var dayName: String {
        if isToday { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        if isTomorrow { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: selectedDate)
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: selectedDate)
    }

    // Live preview macros for grams mode
    private var previewGrams: Float {
        guard mode == .grams, pendingFood != nil else { return 0 }
        return Float(inputText) ?? 0
    }

    private var previewMacros: Macros? {
        guard let food = pendingFood, previewGrams > 0 else { return nil }
        return food.macros(forGrams: previewGrams)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header - outside ScrollView, immune to slide animation
                headerView
                    .padding(.horizontal, 18)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Transitioning content
                            VStack(alignment: .leading, spacing: 0) {
                                // Day summary
                                DaySummaryView(
                                    cal: logService.totalCalories,
                                    protein: logService.totalProtein,
                                    carbs: logService.totalCarbs,
                                    fat: logService.totalFat,
                                    profile: authService.profile
                                )
                                .padding(.bottom, 24)

                                // Food entries (notepad)
                                mealEntriesView

                                // New meal divider - shows after double-enter
                                if !logService.todayEntries.isEmpty {
                                    let latestMeal = logService.todayEntries.map(\.mealIndex).max() ?? 0
                                    if currentMealIndex > latestMeal {
                                        let existingMealCount = groupedEntries().count

                                        Rectangle()
                                            .fill(Color.white.opacity(0.04))
                                            .frame(height: 1)
                                            .padding(.top, 9)
                                            .padding(.bottom, 8)

                                        HStack {
                                            Text("Meal \(existingMealCount + 1)")
                                                .font(.labelMealHeader)
                                                .foregroundColor(.textMuted)
                                                .textCase(.uppercase)
                                                .tracking(0.8)
                                            Spacer()
                                        }
                                        .padding(.bottom, 2)
                                    }
                                }

                                // Inline input area
                                if logService.todayEntries.isEmpty {
                                    HStack {
                                        Text("Meal 1")
                                            .font(.labelMealHeader)
                                            .foregroundColor(.textMuted)
                                            .textCase(.uppercase)
                                            .tracking(0.8)
                                        Spacer()
                                    }
                                    .padding(.bottom, 2)
                                }

                                // Pending food row (grams mode) — same layout as FoodEntryRow
                                if mode == .grams, let food = pendingFood {
                                    let isFirstInMeal: Bool = {
                                        if logService.todayEntries.isEmpty { return true }
                                        let latestMeal = logService.todayEntries.map(\.mealIndex).max() ?? 0
                                        return currentMealIndex > latestMeal
                                    }()

                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(food.name.capitalized)
                                                .font(.bodyFood)
                                                .foregroundColor(.textPrimary)

                                            // Detail line with inline grams input
                                            HStack(spacing: 10) {
                                                HStack(spacing: 1) {
                                                    TextField(
                                                        "\(Int(food.servingGrams))",
                                                        text: $inputText
                                                    )
                                                    .font(.labelSmall)
                                                    .foregroundColor(.textMuted)
                                                    .keyboardType(.default)
                                                    .autocorrectionDisabled()
                                                    .textInputAutocapitalization(.never)
                                                    .focused($gramsFocused)
                                                    .transaction { $0.animation = nil }
                                                    .onKeyPress(.return) {
                                                        handleSubmit()
                                                        return .handled
                                                    }
                                                    .fixedSize()

                                                    Text("g")
                                                        .font(.labelSmall)
                                                        .foregroundColor(.textMuted)
                                                }

                                                Text("·")
                                                    .font(.labelSmall)
                                                    .foregroundColor(.white.opacity(0.1))

                                                if let macros = previewMacros {
                                                    Text("\(Int(macros.calories))")
                                                        .font(.monoSmall)
                                                        .foregroundColor(.white.opacity(0.4))
                                                    Text("\(Int(macros.protein))p")
                                                        .font(.monoSmall)
                                                        .foregroundColor(.proteinColor)
                                                    Text("\(Int(macros.carbs))c")
                                                        .font(.monoSmall)
                                                        .foregroundColor(.carbColor)
                                                    Text("\(Int(macros.fat))f")
                                                        .font(.monoSmall)
                                                        .foregroundColor(.fatColor)
                                                } else {
                                                    let grams = Float(inputText) ?? food.servingGrams
                                                    let fallbackMacros = food.macros(forGrams: grams)
                                                    Text("\(Int(fallbackMacros.calories))")
                                                        .font(.monoSmall)
                                                        .foregroundColor(.white.opacity(0.4))
                                                    Text("\(Int(fallbackMacros.protein))p")
                                                        .font(.monoSmall)
                                                        .foregroundColor(.proteinColor)
                                                    Text("\(Int(fallbackMacros.carbs))c")
                                                        .font(.monoSmall)
                                                        .foregroundColor(.carbColor)
                                                    Text("\(Int(fallbackMacros.fat))f")
                                                        .font(.monoSmall)
                                                        .foregroundColor(.fatColor)
                                                }
                                            }
                                        }

                                        Spacer()

                                        Button(action: { cancelPending() }) {
                                            Text("×")
                                                .font(.system(size: 15))
                                                .foregroundColor(.white.opacity(0.12))
                                        }
                                        .padding(.top, 2)
                                    }
                                    .padding(.vertical, 5)
                                    .padding(.top, isFirstInMeal ? 0 : -4)
                                }

                                inputAreaView

                                // Bottom padding
                                Spacer().frame(height: 120)
                                    .id("bottom")
                            }
                            .id(selectedDate)
                            .transition(.asymmetric(
                                insertion: .move(edge: slideDirection == .trailing ? .leading : .trailing),
                                removal: .move(edge: slideDirection)
                            ))
                            .animation(.easeInOut(duration: 0.3), value: selectedDate)
                        }
                        .padding(.horizontal, 18)
                        .clipped()
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
        }
        .onTapGesture {
            if mode == .grams {
                gramsFocused = true
            } else {
                inputFocused = true
            }
        }
        .task {
            dateNavAction.onNavigate = { [self] newDate, direction in
                navigateToDate(newDate, direction: direction)
            }
            dateNavAction.selectedDate = selectedDate

            if let userId = authService.userId {
                await logService.loadEntries(userId: userId, date: selectedDate)
                currentMealIndex = logService.todayEntries.map(\.mealIndex).max() ?? 0
            }

            // Auto-focus after data is ready
            try? await Task.sleep(nanoseconds: 200_000_000)
            inputFocused = true
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(authService)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 50, coordinateSpace: .local)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    guard abs(horizontal) > abs(vertical) * 2 else { return }

                    if horizontal < 0 {
                        let cal = Calendar.current
                        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
                        if !cal.isDate(selectedDate, inSameDayAs: tomorrow) {
                            let newDate = cal.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                            navigateToDate(newDate, direction: .leading)
                        }
                    } else {
                        let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                        navigateToDate(newDate, direction: .trailing)
                    }
                }
        )
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(dayName)
                    .font(.headerDay)
                    .foregroundColor(.white)
                    .tracking(-0.8)

                Text(dateString)
                    .font(.headerDate)
                    .foregroundColor(.textSecondary)
            }
            .onTapGesture {
                if !isToday {
                    let direction: Edge = selectedDate < Date() ? .leading : .trailing
                    navigateToDate(Date(), direction: direction)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if let profile = authService.profile, profile.streakCurrent > 0 {
                    HStack(spacing: 2) {
                        Text("🔥")
                            .font(.system(size: 12))
                        Text("\(profile.streakCurrent)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.streakColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.bgStreakBadge)
                    .cornerRadius(10)
                }

                DateNavButtons(actions: dateNavAction)

                SettingsButton {
                    showSettings = true
                }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    // MARK: - Meal entries (notepad style)
    private var mealEntriesView: some View {
        let groups = groupedEntries()
        return ForEach(Array(groups.enumerated()), id: \.offset) { mealIdx, group in
            VStack(alignment: .leading, spacing: 0) {
                // Meal header — also a drop target
                HStack {
                    Text("Meal \(mealIdx + 1)")
                        .font(.labelMealHeader)
                        .foregroundColor(.textMuted)
                        .textCase(.uppercase)
                        .tracking(0.8)

                    Spacer()

                    let mealCal = group.reduce(0) { $0 + $1.calories }
                    Text("\(Int(mealCal)) kcal")
                        .font(.monoTiny)
                        .foregroundColor(.textVeryMuted)
                }
                .padding(.bottom, 2)

                // Food items
                ForEach(group) { entry in
                    FoodEntryRow(entry: entry) {
                        Task {
                            await logService.deleteEntry(entry)
                        }
                    }
                }

                // Divider between meals
                if mealIdx < groups.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 1)
                        .padding(.top, 9)
                        .padding(.bottom, 8)
                }
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Input area
    private var inputAreaView: some View {
        VStack(alignment: .leading, spacing: 0) {

            if mode == .custom {
                HStack {
                    Text(customFoodName.capitalized)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))

                    Text("· custom")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.12))
                        .italic()

                    Spacer()

                    Button("cancel") {
                        cancelCustom()
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.textMuted)
                }
                .padding(.bottom, 4)

                // Step progress dots
                HStack(spacing: 6) {
                    ForEach(CustomStep.allCases, id: \.rawValue) { step in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(step.rawValue < customStep.rawValue
                                    ? Color.calBarBlue.opacity(0.8)
                                    : step == customStep
                                        ? Color.white.opacity(0.5)
                                        : Color.white.opacity(0.1))
                                .frame(width: 5, height: 5)

                            if step == customStep {
                                Text(step.label)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                    }
                    Spacer()

                    // Running preview of entered values
                    if customStep.rawValue > 0 {
                        customPreviewText
                    }
                }
                .padding(.bottom, 4)
            }

            if mode != .grams {
                // Input row (hidden in grams mode — input is inline in pending row)
                HStack(spacing: 10) {
                    TextField(
                        currentPlaceholder,
                        text: $inputText
                    )
                    .font(mode == .search ? .inputSearch : .inputGrams)
                    .foregroundColor(mode == .search ? .textPrimary : .textMuted)
                    .keyboardType(mode == .custom ? .decimalPad : .default)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($inputFocused)
                    .transaction { $0.animation = nil }
                    .onChange(of: inputText) { oldValue, newValue in
                        if mode == .search {
                            foodService.search(query: newValue)

                            if newValue.isEmpty && !oldValue.isEmpty && !suppressUndo {
                                let latestMeal = logService.todayEntries.map(\.mealIndex).max() ?? 0
                                if currentMealIndex > latestMeal {
                                    currentMealIndex = latestMeal
                                }
                            }
                        }
                        suppressUndo = false
                    }
                    .onKeyPress(.return) {
                        handleSubmit()
                        return .handled
                    }

                    if mode == .custom {
                        Text(customStep == .serving ? "g" : customStep == .calories ? "cal" : "g")
                            .font(.system(size: 11))
                            .foregroundColor(.textMuted)
                    }
                }
                .padding(.vertical, 4)
            }

            // Double-enter hint
            if mode == .search && lastWasEnter && inputText.isEmpty && !logService.todayEntries.isEmpty {
                let latestMeal = logService.todayEntries.map(\.mealIndex).max() ?? 0
                if currentMealIndex <= latestMeal {
                    Text("press enter again to start a new meal")
                        .font(.system(size: 11))
                        .foregroundColor(.textVeryMuted)
                        .italic()
                        .padding(.bottom, 4)
                }
            }

            // Search suggestions or "add custom" option
            if mode == .search && !inputText.isEmpty {
                if !foodService.searchResults.isEmpty {
                    SuggestionDropdown(
                        suggestions: foodService.searchResults,
                        onSelect: { food in
                            selectFood(food)
                        }
                    )
                } else if !foodService.isSearching && inputText.trimmingCharacters(in: .whitespaces).count >= 2 {
                    // No results — offer custom food creation
                    Button {
                        startCustomFood()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.calBarBlue.opacity(0.6))

                            Text("Add \"\(inputText.trimmingCharacters(in: .whitespaces))\" as custom food")
                                .font(.system(size: 14))
                                .foregroundColor(.textPrimary)

                            Spacer()

                            Text("enter ↵")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.textVeryMuted)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color.bgDropdown)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.calBarBlue.opacity(0.12), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.top, 4)
    }

    // Dynamic placeholder
    private var currentPlaceholder: String {
        switch mode {
        case .search:
            return logService.todayEntries.isEmpty ? "start typing to log food..." : "add more..."
        case .grams:
            return "\(Int(pendingFood?.servingGrams ?? 100))"
        case .custom:
            return customStep.prompt
        }
    }

    // Running preview of entered custom values
    private var customPreviewText: some View {
        HStack(spacing: 6) {
            if customStep.rawValue > 0 {
                Text("\(Int(customServing))g")
                    .font(.monoTiny)
                    .foregroundColor(.textMuted)
            }
            if customStep.rawValue > 1 {
                Text("\(Int(customCals))")
                    .font(.monoTiny)
                    .foregroundColor(.white.opacity(0.4))
            }
            if customStep.rawValue > 2 {
                Text("\(Int(customProtein))p")
                    .font(.monoTiny)
                    .foregroundColor(.proteinColor)
            }
            if customStep.rawValue > 3 {
                Text("\(Int(customCarbs))c")
                    .font(.monoTiny)
                    .foregroundColor(.carbColor)
            }
        }
    }

    // MARK: - Date Navigation
    private func navigateToDate(_ newDate: Date, direction: Edge) {
        guard let userId = authService.userId else { return }
        slideDirection = direction
        dateNavAction.selectedDate = newDate

        inputText = ""
        mode = .search
        pendingFood = nil
        customFoodName = ""
        customStep = .serving
        lastWasEnter = false
        suppressUndo = true

        Task {
            let entries = await logService.preloadEntries(userId: userId, date: newDate)
            logService.todayEntries = entries
            currentMealIndex = entries.map(\.mealIndex).max() ?? 0
            selectedDate = newDate
        }
    }

    // MARK: - Actions
    private func selectFood(_ food: Food) {
        pendingFood = food
        mode = .grams
        inputText = "\(Int(food.servingGrams))"
        foodService.clearSearch()
        gramsFocused = true
    }

    private func cancelPending() {
        pendingFood = nil
        mode = .search
        suppressUndo = true
        inputText = ""
        DispatchQueue.main.async {
            inputFocused = true
        }
    }

    private func handleSubmit() {
        if mode == .grams {
            confirmFood()
            return
        }

        if mode == .custom {
            advanceCustomStep()
            return
        }

        // Search mode
        if inputText.trimmingCharacters(in: .whitespaces).isEmpty {
            let latestMeal = logService.todayEntries.map(\.mealIndex).max() ?? 0
            let alreadyOnNewMeal = currentMealIndex > latestMeal

            if alreadyOnNewMeal || logService.todayEntries.isEmpty {
                // Do nothing
            } else if lastWasEnter {
                currentMealIndex += 1
                lastWasEnter = false
            } else {
                lastWasEnter = true
            }
        } else {
            if let first = foodService.searchResults.first {
                selectFood(first)
            } else if !foodService.isSearching && inputText.trimmingCharacters(in: .whitespaces).count >= 2 {
                // No results — enter triggers custom food flow
                startCustomFood()
            }
            lastWasEnter = false
        }

        inputFocused = true
    }

    private func confirmFood() {
        guard let food = pendingFood,
              let userId = authService.userId else { return }

        let grams = Float(inputText) ?? food.servingGrams

        Task {
            await logService.addEntry(userId: userId, food: food, grams: grams, mealIndex: currentMealIndex, date: selectedDate)
        }

        pendingFood = nil
        mode = .search
        suppressUndo = true
        inputText = ""
        lastWasEnter = false

        // Focus after next layout pass so the search TextField is in the tree
        DispatchQueue.main.async {
            inputFocused = true
        }
    }

    // MARK: - Custom food flow
    private func startCustomFood() {
        customFoodName = inputText.trimmingCharacters(in: .whitespaces)
        customStep = .serving
        customServing = 100
        customCals = 0
        customProtein = 0
        customCarbs = 0
        mode = .custom
        suppressUndo = true
        inputText = ""
        foodService.clearSearch()
        inputFocused = true
    }

    private func cancelCustom() {
        mode = .search
        customFoodName = ""
        customStep = .serving
        suppressUndo = true
        inputText = ""
        inputFocused = true
    }

    private func advanceCustomStep() {
        let value = Float(inputText) ?? 0

        // Store value for current step
        switch customStep {
        case .serving: customServing = max(value, 1)
        case .calories: customCals = value
        case .protein: customProtein = value
        case .carbs: customCarbs = value
        case .fat:
            // Final step — create the food and log it
            let fatValue = value
            confirmCustomFood(fat: fatValue)
            return
        }

        // Advance to next step
        if let next = customStep.next {
            customStep = next
            inputText = ""
            inputFocused = true
        }
    }

    private func confirmCustomFood(fat: Float) {
        guard let userId = authService.userId else { return }

        // Capture values before resetting state
        let name = customFoodName
        let serving = customServing
        let cals = customCals
        let protein = customProtein
        let carbs = customCarbs
        let meal = currentMealIndex
        let date = selectedDate

        // Reset immediately so UI is responsive
        mode = .search
        customFoodName = ""
        customStep = .serving
        suppressUndo = true
        inputText = ""
        lastWasEnter = false
        inputFocused = true

        Task {
            if let food = await foodService.createCustomFood(
                name: name,
                servingGrams: serving,
                calories: cals,
                protein: protein,
                carbs: carbs,
                fat: fat
            ) {
                await logService.addEntry(
                    userId: userId,
                    food: food,
                    grams: serving,
                    mealIndex: meal,
                    date: date
                )
            }
        }
    }

    // MARK: - Group entries by meal_index
    private func groupedEntries() -> [[FoodLogEntry]] {
        guard !logService.todayEntries.isEmpty else { return [] }
        var groups: [[FoodLogEntry]] = []
        var current: [FoodLogEntry] = []
        var currentMeal = logService.todayEntries.first?.mealIndex ?? 0

        for entry in logService.todayEntries {
            if entry.mealIndex != currentMeal {
                if !current.isEmpty { groups.append(current) }
                current = []
                currentMeal = entry.mealIndex
            }
            current.append(entry)
        }
        if !current.isEmpty { groups.append(current) }
        return groups
    }
}

// MARK: - Day Summary
struct DaySummaryView: View {
    let cal: Float
    let protein: Float
    let carbs: Float
    let fat: Float
    let profile: Profile?

    private var calGoal: Float { Float(profile?.calGoal ?? 2200) }
    private var proteinGoal: Float { Float(profile?.proteinGoal ?? 160) }
    private var carbGoal: Float { Float(profile?.carbGoal ?? 250) }
    private var fatGoal: Float { Float(profile?.fatGoal ?? 70) }
    private var remaining: Float { calGoal - cal }
    private var calPct: CGFloat { min(CGFloat(cal / calGoal), 1) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(Int(cal))")
                        .font(.summaryCalorie)
                        .foregroundColor(.white)
                    Text(" / \(Int(calGoal))")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.textMuted)
                }
                Spacer()
            }
            .padding(.bottom, 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(
                            calPct >= 1
                                ? LinearGradient(colors: [.calBarGreen, .calBarGreenDark], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.calBarBlue, .calBarPurple], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * calPct)
                        .animation(.easeOut(duration: 0.4), value: calPct)
                }
            }
            .frame(height: 3)
            .padding(.bottom, 10)

            HStack(spacing: 16) {
                MacroBar(label: "Protein", value: protein, goal: proteinGoal, color: .proteinColor)
                MacroBar(label: "Carbs", value: carbs, goal: carbGoal, color: .carbColor)
                MacroBar(label: "Fat", value: fat, goal: fatGoal, color: .fatColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.bgCard)
        .cornerRadius(14)
    }
}

struct MacroBar: View {
    let label: String
    let value: Float
    let goal: Float
    let color: Color

    private var pct: CGFloat { min(CGFloat(value / max(goal, 1)), 1) }

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.25))
                Spacer()
                HStack(spacing: 0) {
                    Text("\(Int(value))")
                        .font(.monoSmall)
                        .foregroundColor(color)
                    Text("/\(Int(goal))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.textVeryMuted)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(color.opacity(0.7))
                        .frame(width: geo.size.width * pct)
                        .animation(.easeOut(duration: 0.4), value: pct)
                }
            }
            .frame(height: 2)
        }
    }
}

// MARK: - Food Entry Row
struct FoodEntryRow: View {
    let entry: FoodLogEntry
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.foodName.capitalized)
                    .font(.bodyFood)
                    .foregroundColor(.textPrimary)

                HStack(spacing: 10) {
                    Text("\(Int(entry.grams))g")
                        .font(.labelSmall)
                        .foregroundColor(.textMuted)

                    Text("·")
                        .font(.labelSmall)
                        .foregroundColor(.white.opacity(0.1))

                    Text("\(Int(entry.calories))")
                        .font(.monoSmall)
                        .foregroundColor(.white.opacity(0.4))
                    Text("\(Int(entry.protein))p")
                        .font(.monoSmall)
                        .foregroundColor(.proteinColor)
                    Text("\(Int(entry.carbs))c")
                        .font(.monoSmall)
                        .foregroundColor(.carbColor)
                    Text("\(Int(entry.fat))f")
                        .font(.monoSmall)
                        .foregroundColor(.fatColor)
                }
            }

            Spacer()

            Button(action: onRemove) {
                Text("×")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.12))
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Suggestion Dropdown
struct SuggestionDropdown: View {
    let suggestions: [Food]
    let onSelect: (Food) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(suggestions.prefix(8)) { food in
                Button {
                    onSelect(food)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(food.name.capitalized)
                                .font(.system(size: 14))
                                .foregroundColor(.textPrimary)

                            Text("\(food.servingLabel) · \(Int(food.servingGrams))g")
                                .font(.system(size: 11))
                                .foregroundColor(.textMuted)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Text("\(Int(food.calPerServing))")
                                .font(.monoTiny)
                                .foregroundColor(.white.opacity(0.35))
                            Text("\(Int(food.proteinPerServing))p")
                                .font(.monoTiny)
                                .foregroundColor(.proteinColor)
                            Text("\(Int(food.carbsPerServing))c")
                                .font(.monoTiny)
                                .foregroundColor(.carbColor)
                            Text("\(Int(food.fatPerServing))f")
                                .font(.monoTiny)
                                .foregroundColor(.fatColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                }

                if food.id != suggestions.prefix(8).last?.id {
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 1)
                }
            }
        }
        .background(Color.bgDropdown)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.7), radius: 20, y: 6)
    }
}
