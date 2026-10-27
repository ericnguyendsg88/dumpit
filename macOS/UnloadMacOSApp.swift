import SwiftUI

@main
struct UnloadMacOSApp: App {
    @StateObject private var store = SessionStore()
    @StateObject private var journal = JournalStore()

    var body: some Scene {
        WindowGroup {
            MacRootView()
                .environmentObject(store)
                .environmentObject(journal)
                .tint(ClearTheme.tealDark)
                .frame(minWidth: 900, minHeight: 650)
        }
        .defaultSize(width: 1080, height: 760)
        .windowStyle(.hiddenTitleBar)
    }
}
