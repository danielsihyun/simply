import Foundation
import Supabase
import Combine

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
}
