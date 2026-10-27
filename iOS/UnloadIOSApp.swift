import SwiftUI

@main
struct UnloadIOSApp: App {
    @StateObject private var store = SessionStore()
    @StateObject private var journal = JournalStore()

    var body: some Scene {
        WindowGroup {
            IOSRootView()
                .environmentObject(store)
                .environmentObject(journal)
                .tint(ClearTheme.tealDark)
        }
    }
}
