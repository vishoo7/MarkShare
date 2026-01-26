import SwiftUI

@main
struct MarkShareApp: App {
    @StateObject private var themeManager = ThemeManager()
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .fullScreenCover(isPresented: .init(
                    get: { !hasSeenWelcome },
                    set: { if !$0 { hasSeenWelcome = true } }
                )) {
                    WelcomeView(isPresented: .init(
                        get: { !hasSeenWelcome },
                        set: { if !$0 { hasSeenWelcome = true } }
                    ))
                }
        }
    }
}
