import SwiftUI
import Combine

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
    @FocusState private var inputFocused: Bool

    enum InputMode { case search, grams }

    private var today: Date { Date() }

    private var dayName: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: today)
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: today)
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

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        headerView

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
                                Rectangle()
                                    .fill(Color.white.opacity(0.04))
                                    .frame(height: 1)
                                    .padding(.top, 14)
                                    .padding(.bottom, 4)

                                HStack {
                                    Text("Meal \(currentMealIndex + 1)")
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
                        inputAreaView

                        // Bottom padding
                        Spacer().frame(height: 120)
                            .id("bottom")
                    }
                    .padding(.horizontal, 18)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onTapGesture {
            inputFocused = true
        }
        .task {
            if let userId = authService.userId {
                await logService.loadToday(userId: userId)
                // Resume at the latest meal index
                currentMealIndex = logService.todayEntries.map(\.mealIndex).max() ?? 0
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                inputFocused = true
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text(dayName)
                    .font(.headerDay)
                    .foregroundColor(.white)
                    .tracking(-0.8)

                Text(dateString)
                    .font(.headerDate)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Streak badge
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
        }
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    // MARK: - Meal entries (notepad style)
    private var mealEntriesView: some View {
        let groups = groupedEntries()
        return ForEach(Array(groups.enumerated()), id: \.offset) { mealIdx, group in
            VStack(alignment: .leading, spacing: 0) {
                // Meal header
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
                        .padding(.top, 14)
                        .padding(.bottom, 12)
                }
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Input area
    private var inputAreaView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pending food label (grams mode)
            if mode == .grams, let food = pendingFood {
                HStack {
                    Text(food.name.capitalized)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    Button("cancel") {
                        cancelPending()
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.textMuted)
                }
                .padding(.bottom, 2)
            }

            // Input row
            HStack(spacing: 10) {
                TextField(
                    mode == .grams
                        ? "\(Int(pendingFood?.servingGrams ?? 100))"
                        : logService.todayEntries.isEmpty
                            ? "start typing to log food..."
                            : "add more...",
                    text: $inputText
                )
                .font(mode == .grams ? .inputGrams : .inputSearch)
                .foregroundColor(mode == .grams ? .textMuted : .textPrimary)
                .keyboardType(mode == .grams ? .decimalPad : .default)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($inputFocused)
                .onChange(of: inputText) { _, newValue in
                    if mode == .search {
                        foodService.search(query: newValue)
                    }
                }
                .onSubmit {
                    handleSubmit()
                }

                if mode == .grams {
                    Text("g")
                        .font(.system(size: 11))
                        .foregroundColor(.textMuted)

                    if let macros = previewMacros {
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.1))

                        HStack(spacing: 10) {
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
                        }
                    }
                }
            }
            .padding(.vertical, 4)

            // Double-enter hint
            if mode == .search && lastWasEnter && inputText.isEmpty {
                Text("press enter again to start a new meal")
                    .font(.system(size: 11))
                    .foregroundColor(.textVeryMuted)
                    .italic()
                    .padding(.bottom, 4)
            }

            // Search suggestions dropdown
            if mode == .search && !inputText.isEmpty && !foodService.searchResults.isEmpty {
                SuggestionDropdown(
                    suggestions: foodService.searchResults,
                    onSelect: { food in
                        selectFood(food)
                    }
                )
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Actions
    private func selectFood(_ food: Food) {
        pendingFood = food
        mode = .grams
        inputText = "\(Int(food.servingGrams))"
        foodService.clearSearch()
        // Keep focus, user types grams and hits return
    }

    private func cancelPending() {
        pendingFood = nil
        mode = .search
        inputText = ""
        inputFocused = true
    }

    private func handleSubmit() {
        if mode == .grams {
            confirmFood()
        } else {
            // Search mode
            if inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                if lastWasEnter {
                    // Double enter = new meal
                    currentMealIndex += 1
                    lastWasEnter = false
                } else {
                    lastWasEnter = true
                }
            } else {
                // Select first suggestion
                if let first = foodService.searchResults.first {
                    selectFood(first)
                }
                lastWasEnter = false
            }
        }
    }

    private func confirmFood() {
        guard let food = pendingFood,
              let userId = authService.userId else { return }

        let grams = Float(inputText) ?? food.servingGrams

        Task {
            await logService.addEntry(userId: userId, food: food, grams: grams, mealIndex: currentMealIndex)
        }

        pendingFood = nil
        mode = .search
        inputText = ""
        lastWasEnter = false
        inputFocused = true
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
            // Calorie header
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

                Text(remaining > 0 ? "\(Int(remaining)) left" : "goal hit ✓")
                    .font(.system(size: 12))
                    .foregroundColor(remaining > 0 ? .textSecondary : .proteinColor)
            }
            .padding(.bottom, 8)

            // Calorie progress bar
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

            // Macro bars
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
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.03))
                .frame(height: 1),
            alignment: .bottom
        )
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
