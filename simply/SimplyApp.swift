import SwiftUI

@main
struct SimplyApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var macroColors = MacroColors()

    var body: some Scene {
        WindowGroup {
            Group {
                switch authService.state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.bgPrimary)
                case .signedOut:
                    SignInView()
                case .signedIn:
                    HomeView()
                }
            }
            .environmentObject(authService)
            .environmentObject(macroColors)
            .preferredColorScheme(.dark)
        }
    }
}
