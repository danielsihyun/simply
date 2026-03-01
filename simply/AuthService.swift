import SwiftUI
import Combine
import AuthenticationServices
import Supabase

enum AuthState {
    case loading
    case signedOut
    case signedIn
}

// MARK: - Goals Update DTO
struct GoalsUpdate: Encodable {
    let calGoal: Int
    let proteinGoal: Int
    let carbGoal: Int
    let fatGoal: Int

    enum CodingKeys: String, CodingKey {
        case calGoal = "cal_goal"
        case proteinGoal = "protein_goal"
        case carbGoal = "carb_goal"
        case fatGoal = "fat_goal"
    }
}

final class AuthService: ObservableObject {
    @Published var state: AuthState = .loading
    @Published var userId: UUID?
    @Published var profile: Profile?

    init() {
        Task { @MainActor in
            await checkSession()
        }
    }

    // MARK: - Session check
    @MainActor
    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            self.userId = session.user.id
            await loadProfile()
            self.state = .signedIn
        } catch {
            self.state = .signedOut
        }
    }

    // MARK: - Apple Sign In
    @MainActor
    func signInWithApple(authorization: ASAuthorization) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8)
        else {
            print("Failed to get Apple ID credential")
            return
        }

        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: tokenString
                )
            )
            self.userId = session.user.id
            await loadProfile()
            self.state = .signedIn
        } catch {
            print("Apple Sign In error: \(error)")
        }
    }

    // MARK: - Load profile
    @MainActor
    func loadProfile() async {
        guard let userId else { return }
        do {
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            self.profile = profile
        } catch {
            print("Load profile error: \(error)")
        }
    }

    // MARK: - Update profile goals
    @MainActor
    func updateGoals(cal: Int, protein: Int, carbs: Int, fat: Int) async {
        guard let userId else { return }
        let update = GoalsUpdate(calGoal: cal, proteinGoal: protein, carbGoal: carbs, fatGoal: fat)
        do {
            _ = try await supabase
                .from("profiles")
                .update(update)
                .eq("id", value: userId.uuidString)
                .execute()

            await loadProfile()
        } catch {
            print("Update goals error: \(error)")
        }
    }

    // MARK: - Sign out
    @MainActor
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            self.userId = nil
            self.profile = nil
            self.state = .signedOut
        } catch {
            print("Sign out error: \(error)")
        }
    }
}
