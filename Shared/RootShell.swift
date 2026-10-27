import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case write, dump

    var id: String { rawValue }

    var title: String {
        switch self {
        case .write: "DumpIt"
        case .dump: "The Bin"
        }
    }

    var icon: String {
        switch self {
        case .write: "pencil.and.scribble"
        case .dump: "trash"
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var tab: AppTab = .write
    /// Mirrors the write screen so the nav bar never restarts a live session.
    @Published var isSessionActive = false
    /// Bumped to ask the write screen to drop straight into a session.
    @Published private(set) var newSessionToken = 0

    func goToWriting() {
        if tab == .write && !isSessionActive {
            newSessionToken += 1
        } else if isSessionActive {
            tab = .write
        } else {
            tab = .write
            newSessionToken += 1
        }
    }
}

/// Persistent shell: one tab of content plus the floating glass bar that never
/// leaves the screen.
struct RootShell: View {
    @StateObject private var router = AppRouter()

    var body: some View {
        content
            .environmentObject(router)
            .safeAreaInset(edge: .bottom) {
                GlassNavBar(router: router)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity)
            }
            .clearstateScreen()
            .onOpenURL { url in
                // dumpit://write — the lock screen widget drops you straight in.
                guard url.scheme == "dumpit" else { return }
                if url.host == "bin" {
                    router.tab = .dump
                } else {
                    router.goToWriting()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch router.tab {
        case .write:
            WriteView()
        case .dump:
            HistoryView()
        }
    }
}

struct GlassNavBar: View {
    @ObservedObject var router: AppRouter

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppTab.allCases) { tab in
                button(for: tab)
            }
        }
        .padding(6)
        .liquidGlassCapsule()
        .fixedSize()
    }

    private func button(for tab: AppTab) -> some View {
        let isSelected = router.tab == tab

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                if tab == .write {
                    // The write button is the way into a session, not just a
                    // page — unless one is already running.
                    router.goToWriting()
                } else {
                    router.tab = tab
                }
            }
        } label: {
            HStack(spacing: 7) {
                // The bin's lid swings open when you move into it.
                if tab == .dump {
                    TrashCanIcon(isOpen: isSelected, size: 17)
                } else {
                    Image(systemName: tab.icon)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(tab.title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : ClearTheme.tealDark)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minWidth: 96)
            .background {
                if isSelected {
                    Capsule()
                        .fill(ClearTheme.teal)
                        .shadow(color: ClearTheme.teal.opacity(0.35), radius: 6, y: 2)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab == .write ? "Start a brain dump" : "The bin, where your old thoughts go")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

extension View {
    /// Liquid Glass where the OS has it, material everywhere older. Both sit on
    /// a cream underlay so the bar stays light on the app's paper background
    /// instead of picking up a dark system tint.
    @ViewBuilder
    func liquidGlassCapsule() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self
                .glassEffect(.regular.tint(.white.opacity(0.5)).interactive(), in: .capsule)
                .background(ClearTheme.cream.opacity(0.92), in: Capsule())
                .overlay {
                    Capsule().stroke(ClearTheme.creamDeep, lineWidth: 1)
                }
                .shadow(color: ClearTheme.forest.opacity(0.10), radius: 16, y: 6)
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .background(ClearTheme.cream.opacity(0.92), in: Capsule())
                .overlay {
                    Capsule().stroke(ClearTheme.creamDeep, lineWidth: 1)
                }
                .shadow(color: ClearTheme.forest.opacity(0.10), radius: 16, y: 6)
        }
    }
}
