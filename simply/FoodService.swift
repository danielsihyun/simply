import Foundation
import Combine
import Supabase

final class FoodService: ObservableObject {
    @Published var searchResults: [Food] = []
    @Published var isSearching = false

    private var searchTask: Task<Void, Never>?

    /// Search foods with debounce. Queries the trigram index for fuzzy matching.
    @MainActor
    func search(query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task { @MainActor in
            // Debounce 300ms
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            do {
                let results: [Food] = try await supabase
                    .from("foods")
                    .select()
                    .ilike("name", pattern: "%\(trimmed)%")
                    .order("name")
                    .limit(30)
                    .execute()
                    .value

                guard !Task.isCancelled else { return }
                self.searchResults = results
            } catch {
                if !Task.isCancelled {
                    print("Search error: \(error)")
                    self.searchResults = []
                }
            }

            self.isSearching = false
        }
    }

    @MainActor
    func clearSearch() {
        searchTask?.cancel()
        searchResults = []
        isSearching = false
    }

    /// Look up a food by barcode in the local database
    func lookupByBarcode(code: String) async -> Food? {
        let externalId = "barcode:\(code)"
        do {
            let foods: [Food] = try await supabase
                .from("foods")
                .select()
                .eq("external_id", value: externalId)
                .limit(1)
                .execute()
                .value
            return foods.first
        } catch {
            print("Barcode lookup error: \(error)")
            return nil
        }
    }

    /// Create a custom food and insert into the foods table
    @MainActor
    func createCustomFood(
        name: String,
        servingGrams: Float,
        calories: Float,
        protein: Float,
        carbs: Float,
        fat: Float,
        barcode: String? = nil,
        isCount: Bool = false
    ) async -> Food? {
        let externalId: String
        if let barcode = barcode {
            externalId = "barcode:\(barcode)"
        } else {
            externalId = "custom:\(UUID().uuidString)"
        }

        let servingLabel = isCount ? "\(Int(servingGrams))×" : "\(Int(servingGrams))g"

        let insert = CustomFoodInsert(
            externalId: externalId,
            name: name.lowercased(),
            brand: barcode != nil ? "Scanned" : "Custom",
            servingLabel: servingLabel,
            servingGrams: servingGrams,
            calPerServing: calories,
            proteinPerServing: protein,
            carbsPerServing: carbs,
            fatPerServing: fat,
            isCount: isCount
        )

        do {
            let food: Food = try await supabase
                .from("foods")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value
            return food
        } catch {
            print("Create custom food error: \(error)")
            return nil
        }
    }
}
