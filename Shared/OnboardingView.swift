import SwiftUI

/// Five-beat tour of what DumpIt does, shown on first launch and re-openable
/// any time from "Check onboarding" on the launcher.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0
    @State private var forward = true

    private static let pageCount = 5

    private var isCompact: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Spacer(minLength: 8)

            content
                .id(page)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading)
                            .combined(with: .opacity),
                        removal: .move(edge: forward ? .leading : .trailing)
                            .combined(with: .opacity)
                    )
                )
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 8)

            footer
        }
        .padding(.horizontal, isCompact ? 22 : 32)
        .padding(.top, 12)
        .padding(.bottom, isCompact ? 18 : 26)
        .frame(
            minWidth: isCompact ? nil : 520,
            idealWidth: isCompact ? nil : 620,
            minHeight: isCompact ? nil : 600,
            idealHeight: isCompact ? nil : 680
        )
        .clearstateScreen()
    }

    private var topBar: some View {
        HStack {
            Text("How DumpIt works")
                .font(.footnote.weight(.bold))
                .foregroundStyle(ClearTheme.muted)
            Spacer()
            if page < Self.pageCount - 1 {
                Button("Skip", action: onFinish)
                    .buttonStyle(.plain)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(ClearTheme.tealDark)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case 0:
            OnboardingPage(
                title: "Every day your mind starts out cluttered.",
                message: "DumpIt clears it with one simple journaling method — you write until the noise is out."
            ) {
                ClutterBarDemo()
            }
        case 1:
            OnboardingPage(
                title: "Words disappear as you write.",
                message: "Pause for a few seconds and what you just wrote softens away, so nothing stares back at you. Nothing is deleted — it stays on the page, faint, and you can read it back any time."
            ) {
                FadingWordsDemo()
            }
        case 2:
            OnboardingPage(
                title: "Three rules.",
                message: "They exist to stop you polishing. A dump is not a draft — it only works if you keep moving forward."
            ) {
                SessionRulesDemo()
            }
        case 3:
            OnboardingPage(
                title: "Your brain runs silent ruminations.",
                message: "Half-finished, badly spelled, on repeat. Write them out."
            ) {
                ScatteredThoughtsDemo()
            }
        default:
            OnboardingPage(
                title: "Carry less. Make space.",
                message: "Those thoughts follow you around all day. Empty them out here and you leave room for new thinking, for creativity, for growth."
            ) {
                SpaceForGrowthDemo()
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 16) {
            HStack(spacing: 7) {
                ForEach(0..<Self.pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? ClearTheme.teal : ClearTheme.muted.opacity(0.25))
                        .frame(width: index == page ? 22 : 7, height: 7)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
                }
            }
            .accessibilityLabel("Page \(page + 1) of \(Self.pageCount)")

            HStack(spacing: 12) {
                if page > 0 {
                    Button("Back") { move(by: -1) }
                        .buttonStyle(.bordered)
                        .font(.headline.weight(.bold))
                }

                Button {
                    if page == Self.pageCount - 1 {
                        onFinish()
                    } else {
                        move(by: 1)
                    }
                } label: {
                    Text(page == Self.pageCount - 1 ? "Start dumping" : "Next")
                }
                .buttonStyle(ClearButtonStyle())
            }
            .frame(maxWidth: 420)
        }
    }

    private func move(by delta: Int) {
        let next = min(max(page + delta, 0), Self.pageCount - 1)
        guard next != page else { return }
        forward = delta > 0
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            page = next
        }
    }
}

private struct OnboardingPage<Demo: View>: View {
    let title: String
    let message: String
    @ViewBuilder let demo: Demo

    var body: some View {
        VStack(spacing: 20) {
            demo
                .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                Text(title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.body)
                    .foregroundStyle(ClearTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Demos

/// Beat 1: the clutter bar fills from yellow to green as the demo "writes".
private struct ClutterBarDemo: View {
    @State private var progress = 0.0

    var body: some View {
        VStack(spacing: 12) {
            GlowingClearProgressBar(value: progress, isActive: true, barHeight: 26)

            HStack {
                Label("Rot", systemImage: "circle.fill")
                    .foregroundStyle(ClearTheme.rotDeep)
                Spacer()
                Label("Clear", systemImage: "circle.fill")
                    .foregroundStyle(ClearTheme.teal)
            }
            .font(.caption.weight(.bold))
            .labelStyle(.titleAndIcon)
            .imageScale(.small)

            Text("The bar starts as a pile of rot. Every word you write feeds Pip, who eats through it until it’s all clear.")
                .font(.footnote)
                .foregroundStyle(ClearTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .clearCard()
        .task {
            // Stepped rather than one long animation: the bar runs its own
            // spring on `value`, which would swallow a 3-second ramp.
            while !Task.isCancelled {
                for step in 0...50 {
                    try? await Task.sleep(for: .milliseconds(62))
                    guard !Task.isCancelled else { return }
                    progress = Double(step) / 50
                }
                try? await Task.sleep(for: .seconds(1.6))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.45)) { progress = 0 }
                try? await Task.sleep(for: .seconds(0.9))
            }
        }
    }
}

/// Beat 2: written words soften a few seconds behind the cursor, and can be
/// brought back.
private struct FadingWordsDemo: View {
    private static let words = "i keep replaying that thing i said at lunch and it was fine probably it was fine".split(separator: " ").map(String.init)

    @State private var fadedCount = 0
    @State private var revealed = false

    private var line: Text {
        Self.words.enumerated().reduce(Text("")) { partial, item in
            let isFaded = !revealed && item.offset < fadedCount
            return partial + Text(item.element + " ")
                .foregroundStyle(isFaded ? ClearTheme.muted.opacity(0.16) : ClearTheme.forest)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                Text("Private · fades on pause")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(ClearTheme.tealDark)

            line
                .font(.callout)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeOut(duration: 0.5), value: fadedCount)
                .animation(.easeOut(duration: 0.3), value: revealed)

            Button {
                revealed.toggle()
            } label: {
                Label(
                    revealed ? "Let them fade again" : "Show them again",
                    systemImage: revealed ? "eye.slash" : "eye"
                )
                .font(.footnote.weight(.bold))
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .frame(minHeight: 168, alignment: .top)
        .clearCard()
        .task {
            while !Task.isCancelled {
                if revealed {
                    try? await Task.sleep(for: .milliseconds(300))
                    continue
                }
                if fadedCount >= Self.words.count - 3 {
                    try? await Task.sleep(for: .seconds(2.2))
                    guard !Task.isCancelled else { return }
                    fadedCount = 0
                } else {
                    try? await Task.sleep(for: .milliseconds(420))
                    guard !Task.isCancelled else { return }
                    fadedCount += 1
                }
            }
        }
    }
}

/// Beat 3: the rules of a dump.
private struct SessionRulesDemo: View {
    @State private var struck = false

    private static let rules: [(icon: String, title: String, detail: String)] = [
        ("delete.backward.fill", "No backspace", "The delete key does nothing"),
        ("lock.fill", "No editing", "You cannot go back up the page"),
        ("timer", "One sitting", "Leave and the dump is binned")
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(Self.rules.enumerated()), id: \.offset) { index, rule in
                HStack(spacing: 12) {
                    Image(systemName: rule.icon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(ClearTheme.coral, in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(rule.title)
                            .font(.headline.weight(.bold))
                        Text(rule.detail)
                            .font(.subheadline)
                            .foregroundStyle(ClearTheme.muted)
                    }
                    Spacer(minLength: 0)
                }
                .opacity(struck ? 1 : 0)
                .offset(x: struck ? 0 : -14)
                .animation(
                    .spring(response: 0.42, dampingFraction: 0.75)
                        .delay(Double(index) * 0.14),
                    value: struck
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .clearCard()
        .task { struck = true }
    }
}

/// Beat 4: the loop everyone actually runs — other people's scattered thoughts,
/// typos and all.
private struct ScatteredThoughtsDemo: View {
    private static let thoughts = [
        "did i lock the door or did i just think about locking it",
        "THE EMAIL. i have to send the email",
        "why did i say that in 2019",
        "reply to mom. no seriously. reply to mom",
        "gym tomorrow (lie)",
        "is everyone else behind too or just me"
    ]

    @State private var shown = 0
    @State private var drift = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(Self.thoughts.enumerated()), id: \.offset) { index, thought in
                Text(thought)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(ClearTheme.forest.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        ClearTheme.creamDeep.opacity(0.85),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .rotationEffect(.degrees(Self.angle(for: index)))
                    .offset(
                        x: Self.offset(for: index),
                        y: drift ? -2.5 : 2.5
                    )
                    .frame(maxWidth: .infinity, alignment: Self.alignment(for: index))
                    .opacity(index < shown ? 1 : 0)
                    .animation(
                        .easeInOut(duration: 2.4 + Double(index) * 0.3)
                            .repeatForever(autoreverses: true),
                        value: drift
                    )
                    .animation(.easeOut(duration: 0.45), value: shown)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .clearCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Examples of scattered thoughts other people wrote out")
        .task {
            drift = true
            for index in 0...Self.thoughts.count {
                try? await Task.sleep(for: .milliseconds(230))
                guard !Task.isCancelled else { return }
                shown = index
            }
        }
    }

    private static func angle(for index: Int) -> Double {
        [-2.2, 1.6, -1.1, 2.4, -1.8, 1.2][index % 6]
    }

    private static func offset(for index: Int) -> Double {
        [-6, 8, -3, 10, -8, 4][index % 6]
    }

    private static func alignment(for index: Int) -> Alignment {
        index.isMultiple(of: 2) ? .leading : .trailing
    }
}

/// Beat 5: what the emptied space is for.
private struct SpaceForGrowthDemo: View {
    private static let tags = [
        ("New thoughts", "lightbulb.fill"),
        ("Creativity", "paintbrush.pointed.fill"),
        ("Room to grow", "leaf.fill")
    ]

    @State private var breathe = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(ClearTheme.mint.opacity(0.7))
                    .frame(width: 104, height: 104)
                    .scaleEffect(breathe ? 1.06 : 0.96)
                Circle()
                    .stroke(ClearTheme.teal.opacity(0.26), lineWidth: 8)
                    .frame(width: 86, height: 86)
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(ClearTheme.tealDark)
            }

            HStack(spacing: 8) {
                ForEach(Self.tags, id: \.0) { tag in
                    Label(tag.0, systemImage: tag.1)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            ClearTheme.mint.opacity(0.55),
                            in: Capsule()
                        )
                        .foregroundStyle(ClearTheme.tealDark)
                }
            }
        }
        .padding(20)
        .clearCard()
        .task {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}
