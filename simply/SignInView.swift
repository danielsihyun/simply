import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Text("Simply")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(-1)

                Text("Track what you eat.\nNothing more.")
                    .font(.system(size: 15))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    Task {
                        await authService.signInWithApple(authorization: authorization)
                    }
                case .failure(let error):
                    print("Apple Sign In failed: \(error)")
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 54)
            .cornerRadius(14)
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}
