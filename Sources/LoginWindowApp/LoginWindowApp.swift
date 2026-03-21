import Foundation
import SwiftUI
#if canImport(CloneClient)
import CloneClient
#endif

// MARK: - State

class LoginState {
    var password: String = ""
    var showError: Bool = false
}

// MARK: - Login View

@MainActor func loginView(state: LoginState, width: CGFloat, height: CGFloat) -> some View {
    let cardHeight: CGFloat = 320
    let cardY = (height - cardHeight) / 2

    return ZStack {
        // Semi-transparent backdrop
        Rectangle()
            .fill(Color(red: 0, green: 0, blue: 0, opacity: 0.3))
            .frame(width: width, height: height)

        // Login card
        VStack(spacing: 0) {
            Spacer()
                .frame(height: cardY)

            VStack(spacing: 20) {
                // User avatar circle
                ZStack {
                    RoundedRectangle(cornerRadius: 48)
                        .fill(Color(red: 0.55, green: 0.55, blue: 0.6, opacity: 1))
                        .frame(width: 96, height: 96)
                    Text("U")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Username
                Text("User")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)

                // Password field
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 1, green: 1, blue: 1, opacity: 0.15))
                        .frame(width: 220, height: 36)
                    if state.password.isEmpty {
                        Text("Enter Password")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 1, green: 1, blue: 1, opacity: 0.4))
                    } else {
                        Text(String(repeating: "\u{2022}", count: state.password.count))
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                }

                // Log In button
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.2, green: 0.5, blue: 1.0, opacity: 1))
                        .frame(width: 220, height: 36)
                    Text("Log In")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .onTapGesture {
                    #if canImport(CloneClient)
                    SystemActions.shared.sessionReady()
                    #endif
                }

                if state.showError {
                    Text("Incorrect password")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 1, green: 0.4, blue: 0.4, opacity: 1))
                }
            }
            .frame(width: 340, height: cardHeight)

            Spacer()
        }
        .frame(width: width, height: height)
    }
}

// MARK: - App Entry Point

@main
struct LoginWindowApp: App {
    let state = LoginState()

    var body: some Scene {
        WindowGroup("LoginWindow") {
            loginView(state: state, width: 1280, height: 800)
        }
    }

    #if canImport(CloneClient)
    var configuration: WindowConfiguration {
        WindowConfiguration(title: "LoginWindow", width: 1280, height: 800, role: .loginWindow)
    }

    func onKeyChar(character: String) {
        if character == "\r" || character == "\n" {
            SystemActions.shared.sessionReady()
        } else if character == "\u{7f}" || character == "\u{08}" {
            if !state.password.isEmpty {
                state.password.removeLast()
            }
        } else if character.count == 1, let scalar = character.unicodeScalars.first, scalar.value >= 32 {
            state.password.append(character)
        }
    }
    #endif
}
