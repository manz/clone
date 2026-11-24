import Foundation
import SwiftUI
#if canImport(CloneClient)
import CloneClient
#endif

// MARK: - State

class LoginState {
    let users: [String]
    var selected: Int = 0
    var password: String = ""
    var showError: Bool = false

    init() {
        var u = RealUsers.list()
        // Dev / macOS fallback when there's no realusers dir: a single account.
        if u.isEmpty { u = [ProcessInfo.processInfo.environment["USER"] ?? "user"] }
        users = u
    }

    var selectedUser: String { users[min(selected, users.count - 1)] }
}

// MARK: - Login View

@MainActor func loginView(state: LoginState, width: CGFloat, height: CGFloat) -> some View {
    let multiUser = state.users.count > 1
    let cardHeight: CGFloat = multiUser ? 380 : 320
    let cardY = (height - cardHeight) / 2

    return ZStack {
        // Semi-transparent backdrop
        Rectangle()
            .fill(Color(red: 0, green: 0, blue: 0, opacity: 0.3))
            .frame(width: width, height: height)

        VStack(spacing: 0) {
            Spacer()
                .frame(height: cardY)

            VStack(spacing: 18) {
                // User avatar circle (initial of the selected user)
                ZStack {
                    RoundedRectangle(cornerRadius: 48)
                        .fill(Color(red: 0.55, green: 0.55, blue: 0.6, opacity: 1))
                        .frame(width: 96, height: 96)
                    Text(state.selectedUser.prefix(1).uppercased())
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Selected user name
                Text(state.selectedUser)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)

                // User picker (only when more than one real user)
                if multiUser {
                    VStack(spacing: 4) {
                        ForEach(Array(state.users.enumerated()), id: \.offset) { idx, name in
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(red: 1, green: 1, blue: 1, opacity: idx == state.selected ? 0.25 : 0.08))
                                    .frame(width: 220, height: 28)
                                Text(name)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                            }
                            .onTapGesture {
                                state.selected = idx
                                state.password = ""
                                state.showError = false
                            }
                        }
                    }
                }

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
                    LoginWindowApp.submit(state: state)
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
            LoginWindowApp.submit(state: state)
        } else if character == "\u{7f}" || character == "\u{08}" {
            if !state.password.isEmpty { state.password.removeLast() }
        } else if character.count == 1, let scalar = character.unicodeScalars.first, scalar.value >= 32 {
            state.showError = false
            state.password.append(character)
        }
    }

    // Authenticate the SELECTED real user against PAM (LoginWindow runs as root,
    // so it can verify any account), then hand off: tell the compositor the
    // session is ready and start that user's clone-session.target.
    static func submit(state: LoginState) {
        let user = state.selectedUser
        if LoginAuth.authenticate(user: user, password: state.password) {
            SystemActions.shared.sessionReady()
            SessionLauncher.startSession(user: user)
        } else {
            state.password = ""
            state.showError = true
        }
    }
    #endif
}
