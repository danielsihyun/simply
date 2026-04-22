import SwiftUI

// MARK: - Settings Button (standalone Liquid Glass)
struct SettingsButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.glass)
    }
}

// MARK: - Analytics Button (Liquid Glass)
struct AnalyticsButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.glass)
    }
}

// MARK: - Main View
struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var macroColors: MacroColors
    @StateObject private var logService = LogService()
    @StateObject private var foodService = FoodService()

    @State private var inputText = ""
    @State private var mode: InputMode = .search
    @State private var pendingFood: Food?
    @State private var lastWasEnter = false
    @State private var lastWasBackspace = false
    @State private var currentMealIndex = 0
    @State private var selectedDate = Date()
    @State private var showSettings = false
    @State private var showScanner = false
    @State private var showAnalytics = false
    @State private var customFoodName = ""
    @State private var customStep: CustomStep = .serving
    @State private var customServing: Float = 100
    @State private var customIsCount = false
    @State private var customCals: Float = 0
    @State private var customProtein: Float = 0
    @State private var customCarbs: Float = 0
    @State private var pendingBarcode: String? = nil
    @State private var lastWasCustomBackspace = false
    @State private var isCopyingMeal = false
    @State private var editingEntryId: UUID? = nil
    @State private var slideOffset: CGFloat = 0
    @State private var isSliding = false
    @State private var containerWidth: CGFloat = 400
    @State private var scrollAnchor: String? = nil
    @FocusState private var inputFocused: Bool
    @FocusState private var gramsFocused: Bool

    private static let sentinel = "\u{200B}"

    private var visibleInput: String {
        inputText.replacingOccurrences(of: Self.sentinel, with: "")
    }

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

    private var previewGrams: Float {
        guard mode == .grams, pendingFood != nil else { return 0 }
        return Float(inputText) ?? 0
    }

    private var previewMacros: Macros? {
        guard let food = pendingFood, previewGrams > 0 else { return nil }
        return food.macros(forGrams: previewGrams)
    }

    /// Whether the pending item belongs to a new meal (beyond existing entries)
    private var pendingIsNewMeal: Bool {
        guard mode == .grams, pendingFood != nil else { return false }
        if logService.todayEntries.isEmpty { return false }
        let latestMeal = logService.todayEntries.map(\.mealIndex).max() ?? 0
        return currentMealIndex > latestMeal
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                headerView
                    .padding(.horizontal, 18)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            VStack(alignment: .leading, spacing: 0) {
                                DaySummaryView(
                                    cal: logService.totalCalories,
                                    protein: logService.totalProtein,
                                    carbs: logService.totalCarbs,
                                    fat: logService.totalFat,
                                    profile: authService.profile
                                )
                                .padding(.bottom, 24)
                                .id("top")

                                mealEntriesView
                                inputAreaView
                                    .id("input")
                            }
                            .offset(x: slideOffset)
                            .clipped()

                            Spacer().frame(height: 120)
                                .id("bottom")
                        }
                        .padding(.horizontal, 18)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onGeometryChange(for: CGFloat.self) { geo in
                        geo.size.width
                    } action: { newWidth in
                        if newWidth > 0 { containerWidth = newWidth }
                    }
                    .onChange(of: scrollAnchor) { _, anchor in
                        guard let anchor else { return }
                        proxy.scrollTo(anchor, anchor: anchor == "top" ? .top : .bottom)
                        scrollAnchor = nil
                    }
                }
            }
        }
        .onTapGesture {
            if editingEntryId != nil {
                editingEntryId = nil
            }

            if mode == .grams {
                gramsFocused = true
            } else {
                inputFocused = true
            }
        }
        .task {
            inputText = Self.sentinel
            // Focus runs on its own clock — the keyboard shouldn't wait on the network.
            // AuthService.checkSession / signInWithApple already loaded the profile before
            // setting state = .signedIn, so we don't refetch it here.
            Task {
                try? await Task.sleep(nanoseconds: 200_000_000)
                inputFocused = true
            }
            if let userId = authService.userId {
                async let entriesLoad: Void = logService.loadEntries(userId: userId, date: selectedDate)
                async let loggedIdsLoad: Void = logService.loadLoggedFoodIds(userId: userId)
                _ = await (entriesLoad, loggedIdsLoad)
                currentMealIndex = logService.todayEntries.map(\.mealIndex).max() ?? 0
                logService.pushToWidget(profile: authService.profile, macroColors: macroColors)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(authService)
                .environmentObject(macroColors)
        }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerView(foodService: foodService) { result in
                handleScanResult(result)
            }
        }
        .sheet(isPresented: $showAnalytics) {
            AnalyticsView()
                .environmentObject(authService)
                .environmentObject(macroColors)
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

    // MARK: - Pending food row (identical layout to FoodEntryRow)
    @ViewBuilder
    private func pendingFoodRow(food: Food) -> some View {
        let grams = Float(inputText) ?? food.servingGrams
        let macros = food.macros(forGrams: grams)
        let unitLabel = food.isCount ? "×" : "g"

        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name.capitalized)
                    .font(.bodyFood)
                    .foregroundColor(.textPrimary)

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
                        .onSubmit {
                            handleSubmit()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                inputFocused = true
                            }
                        }
                        .fixedSize()

                        Text(unitLabel)
                            .font(.labelSmall)
                            .foregroundColor(.textMuted)
                    }
                    .frame(height: 16, alignment: .leading)

                    Text("·")
                        .font(.labelSmall)
                        .foregroundColor(.white.opacity(0.1))

                    Text("\(Int(macros.calories))")
                        .font(.monoSmall)
                        .foregroundColor(.white.opacity(0.4))
                    Text("\(Int(macros.protein))p")
                        .font(.monoSmall)
                        .foregroundColor(macroColors.protein)
                    Text("\(Int(macros.carbs))c")
                        .font(.monoSmall)
                        .foregroundColor(macroColors.carbs)
                    Text("\(Int(macros.fat))f")
                        .font(.monoSmall)
                        .foregroundColor(macroColors.fat)
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
    }

    // MARK: - Copy Yesterday Button
    private var copyYesterdayButton: some View {
        Button {
            copyYesterdayMeal()
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textMuted)
                .frame(width: 20, height: 20)
        }
        .disabled(isCopyingMeal)
        .opacity(isCopyingMeal ? 0.4 : 1.0)
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
                AnalyticsButton {
                    showAnalytics = true
                }

                BarcodeScanButton {
                    showScanner = true
                }

                SettingsButton {
                    showSettings = true
                }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    // MARK: - Meal header (unified to prevent layout shift)
    @ViewBuilder
    private func mealHeader(index: Int, calories: Float, showCopy: Bool, onDelete: (() -> Void)? = nil) -> some View {
        HStack {
            Text("Meal \(index)")
                .font(.labelMealHeader)
                .foregroundColor(.textMuted)
                .textCase(.uppercase)
                .tracking(0.8)

            Spacer()

            ZStack {
                // Cal count + delete button — visible when meal has entries
                HStack(spacing: 8) {
                    Text("\(Int(calories)) cal")
                        .font(.monoTiny)
                        .foregroundColor(.textVeryMuted)

                    if let onDelete {
                        Button(action: onDelete) {
                            Text("×")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.12))
                        }
                    }
                }
                .opacity(calories > 0 ? 1 : 0)
                .allowsHitTesting(calories > 0)

                // Copy button — visible when meal is empty and no pending
                copyYesterdayButton
                    .opacity(showCopy ? 1 : 0)
                    .allowsHitTesting(showCopy)
            }
        }
        .padding(.bottom, 2)
    }

    // MARK: - Meal entries (pending item rendered inline)
    private var mealEntriesView: some View {
        let groups = groupedEntries()
        let hasPending = mode == .grams && pendingFood != nil
        let latestMeal = logService.todayEntries.map(\.mealIndex).max() ?? 0

        // Whether we need an extra empty meal slot at the bottom
        let needsExtraMeal = groups.isEmpty || currentMealIndex > latestMeal
        let extraMealDisplayIndex = groups.isEmpty ? 1 : groups.count + 1

        return VStack(alignment: .leading, spacing: 0) {
            // Render each existing meal group
            ForEach(Array(groups.enumerated()), id: \.offset) { mealIdx, group in
                let isLastGroup = mealIdx == groups.count - 1
                let pendingBelongsHere = hasPending && !pendingIsNewMeal && isLastGroup
                let mealCal = group.reduce(0) { $0 + $1.calories }
                let groupMealIndex = group.first?.mealIndex ?? mealIdx

                VStack(alignment: .leading, spacing: 0) {
                    mealHeader(
                        index: mealIdx + 1,
                        calories: mealCal,
                        showCopy: false,
                        onDelete: {
                            guard let userId = authService.userId else { return }
                            let dateToDelete = selectedDate
                            let indexToDelete = groupMealIndex
                            Task {
                                await logService.deleteMeal(userId: userId, date: dateToDelete, mealIndex: indexToDelete)
                                if currentMealIndex > indexToDelete {
                                    currentMealIndex -= 1
                                }
                                await authService.loadProfile()
                                logService.pushToWidget(profile: authService.profile, macroColors: macroColors)
                            }
                        }
                    )

                    ForEach(group) { entry in
                        FoodEntryRow(
                            entry: entry,
                            isEditing: editingEntryId == entry.id,
                            onTapToEdit: {
                                editingEntryId = entry.id
                            },
                            onCancelEdit: {
                                editingEntryId = nil
                            },
                            onRemove: {
                                Task {
                                    await logService.deleteEntry(entry)
                                    await authService.loadProfile()
                                    logService.pushToWidget(profile: authService.profile, macroColors: macroColors)
                                }
                            },
                            onUpdateGrams: { newGrams in
                                editingEntryId = nil
                                Task {
                                    await logService.updateEntryGrams(entry, newGrams: newGrams)
                                    await authService.loadProfile()
                                    logService.pushToWidget(profile: authService.profile, macroColors: macroColors)
                                }
                            }
                        )
                    }

                    // Pending item appended to the last existing meal group
                    if pendingBelongsHere, let food = pendingFood {
                        pendingFoodRow(food: food)
                    }

                    // Divider between meal groups (not after last unless new meal follows)
                    if !isLastGroup || needsExtraMeal {
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 1)
                            .padding(.top, 9)
                            .padding(.bottom, 8)
                    }
                }
                .padding(.bottom, 4)
            }

            // Extra meal slot: empty Meal 1, new meal via double-enter, or pending new meal
            if needsExtraMeal {
                let pendingHere = hasPending && (groups.isEmpty || pendingIsNewMeal)

                VStack(alignment: .leading, spacing: 0) {
                    mealHeader(
                        index: extraMealDisplayIndex,
                        calories: 0,
                        showCopy: !pendingHere
                    )

                    if pendingHere, let food = pendingFood {
                        pendingFoodRow(food: food)
                    }
                }
                .padding(.bottom, 4)
            }
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

                    if customStep.rawValue > 0 {
                        customPreviewText
                    }
                }
                .padding(.bottom, 4)
            }

            if mode != .grams {
                HStack(spacing: 10) {
                    ZStack(alignment: .leading) {
                        if mode == .search && visibleInput.isEmpty {
                            Text(currentPlaceholder)
                                .font(.inputSearch)
                                .foregroundColor(.textMuted)
                                .allowsHitTesting(false)
                        } else if mode == .custom && visibleInput.isEmpty {
                            Text(currentPlaceholder)
                                .font(.inputGrams)
                                .foregroundColor(.textMuted)
                                .allowsHitTesting(false)
                        }

                        TextField(
                            "",
                            text: $inputText
                        )
                    .font(mode == .search ? .inputSearch : .inputGrams)
                    .foregroundColor(mode == .search ? .textPrimary : .textMuted)
                    .keyboardType(mode == .custom ? .numbersAndPunctuation : .default)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($inputFocused)
                    .transaction { $0.animation = nil }
                    .onChange(of: inputText) { oldValue, newValue in
                        let oldVisible = oldValue.replacingOccurrences(of: Self.sentinel, with: "")
                        let newVisible = newValue.replacingOccurrences(of: Self.sentinel, with: "")

                        if mode == .search && newValue.isEmpty && oldValue == Self.sentinel {
                            handleBackspace()
                            inputText = Self.sentinel
                            return
                        }

                        if mode == .custom && newValue.isEmpty && oldValue == Self.sentinel {
                            handleCustomBackspace()
                            inputText = Self.sentinel
                            return
                        }

                        if mode == .search {
                            foodService.search(query: newVisible)

                            if newVisible.isEmpty && !oldVisible.isEmpty && newValue != Self.sentinel {
                                inputText = Self.sentinel
                                return
                            }
                        }

                        if mode == .custom && newVisible.isEmpty && !oldVisible.isEmpty && newValue != Self.sentinel {
                            inputText = Self.sentinel
                            return
                        }
                        if !newVisible.isEmpty && newValue.contains(Self.sentinel) {
                            inputText = newVisible
                            return
                        }
                        if !newVisible.isEmpty {
                            lastWasBackspace = false
                            lastWasEnter = false
                            lastWasCustomBackspace = false
                        }
                    }
                    .onKeyPress(.return) {
                        handleSubmit()
                        lastWasBackspace = false
                        return .handled
                    }
                    .onKeyPress(.delete) {
                        guard visibleInput.isEmpty else { return .ignored }
                        if mode == .search {
                            handleBackspace()
                        } else if mode == .custom {
                            handleCustomBackspace()
                        }
                        return .handled
                    }
                    .onSubmit {
                        handleSubmit()
                        lastWasBackspace = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            if mode == .grams {
                                gramsFocused = true
                            } else {
                                inputFocused = true
                            }
                        }
                    }
                    }

                    if mode == .custom {
                        if customStep == .serving {
                            Button {
                                customIsCount.toggle()
                            } label: {
                                Text(customIsCount ? "ct" : "g")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color.calBarBlue.opacity(0.7))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.calBarBlue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        } else {
                            Text(customStep == .calories ? "cal test 2" : "g")
                                .font(.system(size: 11))
                                .foregroundColor(.textMuted)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if mode == .search && lastWasEnter && visibleInput.isEmpty && !logService.todayEntries.isEmpty {
                let latestMeal = logService.todayEntries.map(\.mealIndex).max() ?? 0
                if currentMealIndex <= latestMeal {
                    Text("press enter again to start a new meal")
                        .font(.system(size: 11))
                        .foregroundColor(.textVeryMuted)
                        .italic()
                        .padding(.bottom, 4)
                }
            }

            if mode == .search && lastWasBackspace && visibleInput.isEmpty && !logService.todayEntries.isEmpty {
                let latestMeal = logService.todayEntries.map(\.mealIndex).max() ?? 0
                let onEmptyNewMeal = currentMealIndex > latestMeal
                Text(onEmptyNewMeal
                     ? "press delete again to remove meal"
                     : "press delete again to remove last entry")
                    .font(.system(size: 11))
                    .foregroundColor(.textVeryMuted)
                    .italic()
                    .padding(.bottom, 4)
            }

            if mode == .custom && lastWasCustomBackspace && visibleInput.isEmpty {
                Text(customStep == .serving
                     ? "press delete again to cancel"
                     : "press delete again to go back")
                    .font(.system(size: 11))
                    .foregroundColor(.textVeryMuted)
                    .italic()
                    .padding(.bottom, 4)
            }

            if mode == .search && !visibleInput.isEmpty {
                let trimmedQuery = visibleInput.trimmingCharacters(in: .whitespaces)
                let canCreate = !foodService.isSearching && trimmedQuery.count >= 2
                if !foodService.searchResults.isEmpty {
                    SuggestionDropdown(
                        suggestions: sortedSearchResults,
                        createQuery: canCreate ? trimmedQuery : nil,
                        onSelect: { food in
                            selectFood(food)
                        },
                        onCreate: {
                            startCustomFood()
                        }
                    )
                } else if canCreate {
                    Button {
                        startCustomFood()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.calBarBlue.opacity(0.6))

                            Text("Add \"\(trimmedQuery)\" as custom food")
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

    private var sortedSearchResults: [Food] {
        let logged = logService.loggedFoodIds
        guard !logged.isEmpty else { return foodService.searchResults }
        return foodService.searchResults.enumerated()
            .sorted { lhs, rhs in
                let l = logged.contains(lhs.element.id)
                let r = logged.contains(rhs.element.id)
                if l != r { return l && !r }
                return lhs.offset < rhs.offset
            }
            .map { $0.element }
    }

    private var currentPlaceholder: String {
        switch mode {
        case .search:
            return logService.todayEntries.isEmpty ? "start typing to log food..." : "add more..."
        case .grams:
            return "\(Int(pendingFood?.servingGrams ?? 100))"
        case .custom:
            if customStep == .serving {
                return customIsCount ? "count per serving" : "serving size in grams"
            }
            if customStep == .calories {
                return customIsCount ? "calories per serving" : "calories per serving"
            }
            if customStep == .protein {
                return customIsCount ? "protein per serving (g)" : "protein (g)"
            }
            if customStep == .carbs {
                return customIsCount ? "carbs per serving (g)" : "carbs (g)"
            }
            if customStep == .fat {
                return customIsCount ? "fat per serving (g)" : "fat (g)"
            }
            return customStep.prompt
        }
    }

    private var customPreviewText: some View {
        HStack(spacing: 6) {
            if customStep.rawValue > 0 {
                Text("\(Int(customServing))\(customIsCount ? "×" : "g")")
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
                    .foregroundColor(macroColors.protein)
            }
            if customStep.rawValue > 3 {
                Text("\(Int(customCarbs))c")
                    .font(.monoTiny)
                    .foregroundColor(macroColors.carbs)
            }
        }
    }

    // MARK: - Date Navigation
    private func navigateToDate(_ newDate: Date, direction: Edge) {
        guard let userId = authService.userId, !isSliding else { return }
        isSliding = true

        inputText = Self.sentinel
        mode = .search
        pendingFood = nil
        customFoodName = ""
        customStep = .serving
        customIsCount = false
        lastWasEnter = false
        lastWasBackspace = false
        pendingBarcode = nil
        editingEntryId = nil

        let exitOffset: CGFloat = direction == .trailing ? containerWidth : -containerWidth
        let phaseDuration: TimeInterval = 0.15

        // Phase 1: slide current content off-screen
        withAnimation(.easeIn(duration: phaseDuration)) {
            slideOffset = exitOffset
        }

        let cal = Calendar.current
        let isLiveDay = cal.isDateInToday(newDate) || cal.isDateInTomorrow(newDate)

        // Phase 2: at the midpoint, swap content and slide in from the opposite side
        DispatchQueue.main.asyncAfter(deadline: .now() + phaseDuration) {
            logService.todayEntries = []
            currentMealIndex = 0
            selectedDate = newDate
            slideOffset = -exitOffset

            // Reset to top immediately for past days — "top" is a stable anchor, so this
            // works regardless of whether entries have loaded yet.
            if !isLiveDay {
                scrollAnchor = "top"
            }

            withAnimation(.easeOut(duration: phaseDuration)) {
                slideOffset = 0
            }

            // Keyboard only comes up for today/tomorrow; past days are read-only browsing.
            inputFocused = isLiveDay

            // Fetch entries in parallel — arrives after the slide-in is already visible
            let targetDateString = logService.dateString(for: newDate)
            Task {
                let entries = await logService.preloadEntries(userId: userId, date: newDate)
                guard logService.dateString(for: selectedDate) == targetDateString else { return }
                logService.todayEntries = entries
                currentMealIndex = entries.map(\.mealIndex).max() ?? 0
                logService.pushToWidget(profile: authService.profile, macroColors: macroColors)

                // Scroll to input AFTER entries are laid out — otherwise the ScrollView
                // has nothing below the input to scroll past, and scrollTo is a no-op.
                if isLiveDay {
                    DispatchQueue.main.async {
                        scrollAnchor = "input"
                    }
                }
            }

            // Unlock swiping after the slide-in animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + phaseDuration + 0.05) {
                isSliding = false
            }
        }
    }

    // MARK: - Copy Yesterday's Meal
    private func copyYesterdayMeal() {
        guard let userId = authService.userId else { return }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        let targetDate = selectedDate
        let targetMeal = currentMealIndex

        // Figure out what display position (0-based) the current meal is at.
        // Today's groups give us the ordered list of meal indices;
        // the current empty meal slot is one beyond the last group.
        let todayGroups = groupedEntries()
        let todayMealIndices = todayGroups.map { $0.first?.mealIndex ?? 0 }
        let displayPosition: Int
        if let pos = todayMealIndices.firstIndex(of: targetMeal) {
            displayPosition = pos
        } else {
            // Current meal is a new empty slot beyond existing groups
            displayPosition = todayGroups.count
        }

        isCopyingMeal = true

        Task {
            let yesterdayEntries = await logService.preloadEntries(userId: userId, date: yesterday)

            // Group yesterday's entries the same way we group today's
            let yesterdayMealIndices = Array(Set(yesterdayEntries.map(\.mealIndex))).sorted()
            let matchingEntries: [FoodLogEntry]

            if displayPosition < yesterdayMealIndices.count {
                // Match by display position — the Nth meal group
                let yesterdayMealIndex = yesterdayMealIndices[displayPosition]
                matchingEntries = yesterdayEntries.filter { $0.mealIndex == yesterdayMealIndex }
            } else if let lastMeal = yesterdayMealIndices.last {
                // Fallback: copy the last meal from yesterday
                matchingEntries = yesterdayEntries.filter { $0.mealIndex == lastMeal }
            } else {
                matchingEntries = []
            }

            if matchingEntries.isEmpty {
                await MainActor.run { isCopyingMeal = false }
                return
            }

            for entry in matchingEntries {
                await logService.copyEntry(entry, userId: userId, toDate: targetDate, mealIndex: targetMeal)
            }

            await logService.loadEntries(userId: userId, date: targetDate)
            await authService.loadProfile()
            logService.pushToWidget(profile: authService.profile, macroColors: macroColors)

            await MainActor.run { isCopyingMeal = false }
        }
    }

    // MARK: - Actions
    private func handleScanResult(_ result: ScanResult) {
        switch result {
        case .existingFood(let food):
            selectFood(food)

        case .scannedFood(let scanned, let barcode):
            Task {
                let servingCal = scanned.caloriesPer100g * scanned.servingGrams / 100
                let servingProtein = scanned.proteinPer100g * scanned.servingGrams / 100
                let servingCarbs = scanned.carbsPer100g * scanned.servingGrams / 100
                let servingFat = scanned.fatPer100g * scanned.servingGrams / 100

                if let food = await foodService.createCustomFood(
                    name: scanned.name,
                    servingGrams: scanned.servingGrams,
                    calories: servingCal,
                    protein: servingProtein,
                    carbs: servingCarbs,
                    fat: servingFat,
                    barcode: barcode
                ) {
                    await MainActor.run {
                        selectFood(food)
                    }
                }
            }

        case .notFound(let barcode):
            pendingBarcode = barcode
            inputFocused = true
        }
    }

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
        inputText = Self.sentinel
        pendingBarcode = nil
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

        if visibleInput.trimmingCharacters(in: .whitespaces).isEmpty {
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
            if let first = sortedSearchResults.first {
                selectFood(first)
            } else if !foodService.isSearching && visibleInput.trimmingCharacters(in: .whitespaces).count >= 2 {
                startCustomFood()
            }
            lastWasEnter = false
        }

        inputFocused = true
    }

    private func handleBackspace() {
        let latestMeal = logService.todayEntries.map(\.mealIndex).max() ?? 0
        let onEmptyNewMeal = currentMealIndex > latestMeal

        if onEmptyNewMeal {
            if lastWasBackspace {
                currentMealIndex = latestMeal
                lastWasBackspace = false
            } else {
                lastWasBackspace = true
                lastWasEnter = false
            }
        } else {
            guard !logService.todayEntries.isEmpty else { return }

            if lastWasBackspace {
                let currentMealEntries = logService.todayEntries.filter { $0.mealIndex == currentMealIndex }
                if let lastEntry = currentMealEntries.last {
                    Task {
                        await logService.deleteEntry(lastEntry)
                        await authService.loadProfile()
                        logService.pushToWidget(profile: authService.profile, macroColors: macroColors)
                    }
                }
                lastWasBackspace = false
            } else {
                lastWasBackspace = true
                lastWasEnter = false
            }
        }
    }

    private func handleCustomBackspace() {
        if lastWasCustomBackspace {
            lastWasCustomBackspace = false
            if customStep == .serving {
                cancelCustom()
            } else if let prev = CustomStep(rawValue: customStep.rawValue - 1) {
                customStep = prev
                switch prev {
                case .serving: inputText = "\(Int(customServing))"
                case .calories: inputText = "\(Int(customCals))"
                case .protein: inputText = "\(Int(customProtein))"
                case .carbs: inputText = "\(Int(customCarbs))"
                case .fat: break
                }
                inputFocused = true
            }
        } else {
            lastWasCustomBackspace = true
        }
    }

    private func confirmFood() {
        guard let food = pendingFood,
              let userId = authService.userId else { return }

        let grams = Float(inputText) ?? food.servingGrams

        Task {
            await logService.addEntry(userId: userId, food: food, grams: grams, mealIndex: currentMealIndex, date: selectedDate)
            await authService.loadProfile()
            logService.pushToWidget(profile: authService.profile, macroColors: macroColors)
        }

        pendingFood = nil
        mode = .search
        inputText = Self.sentinel
        lastWasEnter = false
        lastWasBackspace = false
        pendingBarcode = nil

        DispatchQueue.main.async {
            inputFocused = true
        }
    }

    // MARK: - Custom food flow
    private func startCustomFood() {
        customFoodName = visibleInput.trimmingCharacters(in: .whitespaces)
        customStep = .serving
        customServing = 100
        customIsCount = false
        customCals = 0
        customProtein = 0
        customCarbs = 0
        mode = .custom
        lastWasCustomBackspace = false
        inputText = Self.sentinel
        foodService.clearSearch()
        inputFocused = true
    }

    private func cancelCustom() {
        mode = .search
        customFoodName = ""
        customStep = .serving
        customIsCount = false
        lastWasCustomBackspace = false
        inputText = Self.sentinel
        pendingBarcode = nil
        inputFocused = true
    }

    private func advanceCustomStep() {
        let value = Float(visibleInput) ?? 0

        switch customStep {
        case .serving: customServing = max(value, 1)
        case .calories: customCals = value
        case .protein: customProtein = value
        case .carbs: customCarbs = value
        case .fat:
            let fatValue = value
            confirmCustomFood(fat: fatValue)
            return
        }

        if let next = customStep.next {
            customStep = next
            lastWasCustomBackspace = false
            inputText = Self.sentinel
            inputFocused = true
        }
    }

    private func confirmCustomFood(fat: Float) {
        guard let userId = authService.userId else { return }

        let name = customFoodName
        let serving = customServing
        let isCount = customIsCount
        let cals = customCals
        let protein = customProtein
        let carbs = customCarbs
        let meal = currentMealIndex
        let date = selectedDate
        let barcode = pendingBarcode

        mode = .search
        customFoodName = ""
        customStep = .serving
        customIsCount = false
        inputText = Self.sentinel
        lastWasEnter = false
        pendingBarcode = nil
        inputFocused = true

        Task {
            if let food = await foodService.createCustomFood(
                name: name,
                servingGrams: serving,
                calories: cals,
                protein: protein,
                carbs: carbs,
                fat: fat,
                barcode: barcode,
                isCount: isCount
            ) {
                await logService.addEntry(
                    userId: userId,
                    food: food,
                    grams: serving,
                    mealIndex: meal,
                    date: date
                )
                await authService.loadProfile()
                logService.pushToWidget(profile: authService.profile, macroColors: macroColors)
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
    @EnvironmentObject var macroColors: MacroColors

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
                        .fill(cal > calGoal + 100 ? Color.red : macroColors.calories)
                        .frame(width: geo.size.width * calPct)
                        .animation(.easeOut(duration: 0.4), value: calPct)
                }
            }
            .frame(height: 3)
            .padding(.bottom, 10)

            HStack(spacing: 16) {
                MacroBar(label: "Protein", value: protein, goal: proteinGoal, color: macroColors.protein)
                MacroBar(label: "Carbs", value: carbs, goal: carbGoal, color: macroColors.carbs)
                MacroBar(label: "Fat", value: fat, goal: fatGoal, color: macroColors.fat)
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

// MARK: - Food Entry Row (with tap-to-edit grams)
struct FoodEntryRow: View {
    @EnvironmentObject var macroColors: MacroColors

    let entry: FoodLogEntry
    let isEditing: Bool
    let onTapToEdit: () -> Void
    let onCancelEdit: () -> Void
    let onRemove: () -> Void
    let onUpdateGrams: (Float) -> Void

    @State private var editText = ""
    @FocusState private var editFocused: Bool

    /// The display unit for this entry — "×" for count-based, "g" for grams
    private var unitLabel: String {
        entry.isCount ? "×" : "g"
    }

    /// Recalculate macros proportionally from the entry's stored values
    private func previewMacros(forGrams g: Float) -> (cal: Float, protein: Float, carbs: Float, fat: Float) {
        let currentGrams = entry.grams
        guard currentGrams > 0 else { return (0, 0, 0, 0) }
        let ratio = g / currentGrams
        return (
            entry.calories * ratio,
            entry.protein * ratio,
            entry.carbs * ratio,
            entry.fat * ratio
        )
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.foodName.capitalized)
                    .font(.bodyFood)
                    .foregroundColor(.textPrimary)

                HStack(spacing: 10) {
                    HStack(spacing: 1) {
                        if isEditing {
                            TextField("\(Int(entry.grams))", text: $editText)
                                .font(.labelSmall)
                                .foregroundColor(.textMuted)
                                .keyboardType(.default)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($editFocused)
                                .fixedSize()
                                .onSubmit { commitEdit() }
                                .onKeyPress(.return) {
                                    commitEdit()
                                    return .handled
                                }
                        } else {
                            Text("\(Int(entry.grams))")
                                .font(.labelSmall)
                                .foregroundColor(.textMuted)
                        }

                        Text(unitLabel)
                            .font(.labelSmall)
                            .foregroundColor(.textMuted)
                    }
                    .frame(height: 16, alignment: .leading)

                    Text("·")
                        .font(.labelSmall)
                        .foregroundColor(.white.opacity(0.1))

                    if isEditing, let editGrams = Float(editText), editGrams > 0 {
                        let preview = previewMacros(forGrams: editGrams)
                        Text("\(Int(preview.cal))")
                            .font(.monoSmall)
                            .foregroundColor(.white.opacity(0.4))
                        Text("\(Int(preview.protein))p")
                            .font(.monoSmall)
                            .foregroundColor(macroColors.protein)
                        Text("\(Int(preview.carbs))c")
                            .font(.monoSmall)
                            .foregroundColor(macroColors.carbs)
                        Text("\(Int(preview.fat))f")
                            .font(.monoSmall)
                            .foregroundColor(macroColors.fat)
                    } else {
                        Text("\(Int(entry.calories))")
                            .font(.monoSmall)
                            .foregroundColor(.white.opacity(0.4))
                        Text("\(Int(entry.protein))p")
                            .font(.monoSmall)
                            .foregroundColor(macroColors.protein)
                        Text("\(Int(entry.carbs))c")
                            .font(.monoSmall)
                            .foregroundColor(macroColors.carbs)
                        Text("\(Int(entry.fat))f")
                            .font(.monoSmall)
                            .foregroundColor(macroColors.fat)
                    }
                }
            }

            Spacer()

            Button(action: {
                if isEditing {
                    onCancelEdit()
                } else {
                    onRemove()
                }
            }) {
                Text("×")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.12))
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                onTapToEdit()
            }
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                editText = "\(Int(entry.grams))"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    editFocused = true
                }
            } else {
                editFocused = false
                editText = ""
            }
        }
    }

    private func commitEdit() {
        guard let newGrams = Float(editText), newGrams > 0 else {
            onCancelEdit()
            return
        }
        onUpdateGrams(newGrams)
    }
}

// MARK: - Suggestion Dropdown
struct SuggestionDropdown: View {
    @EnvironmentObject var macroColors: MacroColors

    let suggestions: [Food]
    let createQuery: String?
    let onSelect: (Food) -> Void
    let onCreate: () -> Void

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

                            Text("\(food.servingLabel) · \(Int(food.servingGrams))\(food.isCount ? "×" : "g")")
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
                                .foregroundColor(macroColors.protein)
                            Text("\(Int(food.carbsPerServing))c")
                                .font(.monoTiny)
                                .foregroundColor(macroColors.carbs)
                            Text("\(Int(food.fatPerServing))f")
                                .font(.monoTiny)
                                .foregroundColor(macroColors.fat)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 1)
            }

            if let query = createQuery {
                Button {
                    onCreate()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.calBarBlue.opacity(0.6))

                        Text("Add \"\(query)\" as custom food")
                            .font(.system(size: 14))
                            .foregroundColor(.textPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
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
