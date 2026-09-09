import SwiftUI

@main
struct JobAgentApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ChatView()
                    .tabItem {
                        Label("Agent Chat", systemImage: "bubble.left.and.bubble.right.fill")
                    }

                ProfileView()
                    .tabItem {
                        Label("Profile & CV", systemImage: "person.crop.circle.fill")
                    }
            }
        }
    }
}
