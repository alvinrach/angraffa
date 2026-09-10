import SwiftUI

@main
struct JobAgentApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            if authViewModel.isAuthenticated {
                TabView {
                    ChatView()
                        .tabItem {
                            Label("Agent Chat", systemImage: "bubble.left.and.bubble.right.fill")
                        }

                    ProfileView(onSignOut: {
                        Task {
                            await authViewModel.signOut()
                        }
                    })
                    .tabItem {
                        Label("Profile & CV", systemImage: "person.crop.circle.fill")
                    }
                }
            } else {
                AuthView(viewModel: authViewModel)
            }
        }
    }
}
