import SwiftUI

enum ProgressTier: Int {
    case idle, early, mid, late, almost, done

    init(progress: Double) {
        switch progress {
        case 0: self = .idle
        case ..<0.25: self = .early
        case ..<0.5: self = .mid
        case ..<0.75: self = .late
        case ..<1: self = .almost
        default: self = .done
        }
    }
}

enum WritingCopy {
    static let sessionPrompts = [
        "What’s taking up space today?",
        "Anything goes.",
        "Dump your thoughts.",
        "Thoughts dump time.",
        "Coffee and dump.",
        "Dump time.",
        "Spill it.",
        "Say the messy version.",
        "Empty the tabs in your head.",
        "Brain, meet page.",
        "No one’s reading. Go.",
        "What’s been looping today?",
        "Type first, think later.",
        "Let the noise out.",
        "Nothing’s off limits here.",
        "Start anywhere.",
        "First thought, no edits."
    ]

    static let placeholders = [
        "Start writing here…",
        "Anything. Really, anything…",
        "Even “I don’t know what to write” counts…",
        "Just start typing…",
        "Messy is fine…",
        "Whatever’s on top of the pile…",
        "Half-sentences welcome…",
        "No punctuation police here…"
    ]

    static func nudges(for tier: ProgressTier) -> [String] {
        switch tier {
        case .idle:
            ["Start writing to charge it.",
             "Type anything — it all counts.",
             "First words are the hardest. Go.",
             "Anything goes. Start there."]
        case .early:
            ["Nice start. Keep the thoughts moving.",
             "That’s the hard part done.",
             "Keep going — no editing.",
             "Warmed up. Keep dumping."]
        case .mid:
            ["You’re making space. Keep going.",
             "Rhythm found. Don’t stop.",
             "More out, more room.",
             "Halfway to halfway."]
        case .late:
            ["More than halfway clear.",
             "Past the hump. Keep unloading.",
             "Downhill from here.",
             "Still plenty in there — let it out."]
        case .almost:
            ["Almost there. Stay with it.",
             "Last stretch. Don’t stop now.",
             "So close. Keep the words coming.",
             "Nearly clear — finish it out."]
        case .done:
            ["Your mind has room to breathe.",
             "All out. Nice work.",
             "That’s a full unload.",
             "Cleared. Enjoy the quiet."]
        }
    }

    /// Picks a fresh line, avoiding an immediate repeat of `current`.
    static func pick(from pool: [String], avoiding current: String? = nil) -> String {
        let fresh = pool.filter { $0 != current }
        return (fresh.isEmpty ? pool : fresh).randomElement() ?? pool[0]
    }
}

struct WriteView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var journal: JournalStore
    @EnvironmentObject private var router: AppRouter
    @FocusState private var isWriting: Bool
    @State private var readyToCash = false
    @State private var cashedIn = false
    @State private var holdProgress = 0.0
    @State private var isHolding = false
    @State private var holdTask: Task<Void, Never>?
    @State private var burst = false
    @State private var fadeTask: Task<Void, Never>?
    @State private var revealTask: Task<Void, Never>?
    @State private var isSessionActive = false
    @State private var showProgress = false
    @State private var showWriting = false
    @State private var isEnteringSession = false
    @State private var sessionPrompt = WritingCopy.pick(from: WritingCopy.sessionPrompts)
    @State private var placeholder = WritingCopy.pick(from: WritingCopy.placeholders)
    @State private var progressTier = ProgressTier.idle
    @State private var progressNudge = WritingCopy.pick(from: WritingCopy.nudges(for: .idle))
    @State private var showOnboarding = false
    @State private var didRecordSession = false
    @State private var sessionStart = Date.now
    @State private var ruleNudge: String?
    @State private var ruleNudgeTask: Task<Void, Never>?
    @State private var confirmLeave = false
    @State private var recoveredDraft: SessionDraft?
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            #if os(iOS)
            iosWritingLayout
            #else
            desktopWritingLayout
            #endif
        }
        .clearstateScreen()
        .onChange(of: store.draft) { _, newValue in
            guard !newValue.isEmpty else { return }
            scheduleFade()
        }
        .onChange(of: store.progress) { _, newValue in
            let tier = ProgressTier(progress: newValue)
            guard tier != progressTier else { return }
            progressTier = tier
            progressNudge = WritingCopy.pick(from: WritingCopy.nudges(for: tier), avoiding: progressNudge)
        }
        .onChange(of: store.hasReachedClearState) { _, reached in
            if reached {
                fadeTask?.cancel()
                recordSession()
                isWriting = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    readyToCash = true
                }
            }
        }
        .onDisappear {
            fadeTask?.cancel()
            revealTask?.cancel()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView { showOnboarding = false }
        }
        .confirmationDialog(
            "Leave this dump?",
            isPresented: $confirmLeave,
            titleVisibility: .visible
        ) {
            Button("Leave — bin it unfinished", role: .destructive) {
                SessionStore.clearDraft()
                recoveredDraft = nil
                returnToLauncher()
            }
            Button("Keep writing", role: .cancel) {}
        } message: {
            Text("A dump has to be finished in one sitting. Leave now and these \(store.wordCount) words are gone for good.")
        }
        .onChange(of: scenePhase) { _, phase in
            // Swiped away or backgrounded mid-dump: keep it recoverable.
            guard phase != .active, isSessionActive, !cashedIn else { return }
            store.persistDraft(startedAt: sessionStart)
        }
        .onChange(of: router.newSessionToken) { _, _ in
            beginSession()
        }
        .onChange(of: isSessionActive) { _, active in
            router.isSessionActive = active
        }
        .task {
            recoveredDraft = SessionStore.loadDraft()
            guard !hasSeenOnboarding else { return }
            hasSeenOnboarding = true
            showOnboarding = true
        }
    }

    private var iosWritingLayout: some View {
        VStack(spacing: 0) {
            if isSessionActive && showProgress {
                compactProgressHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                    .background(ClearTheme.cream)
                    .shadow(color: ClearTheme.forest.opacity(0.08), radius: 10, y: 5)
                    .zIndex(1)
                    .transition(
                        .scale(scale: 0.90, anchor: .top)
                            .combined(with: .opacity)
                    )
            }

            if isSessionActive {
                // No ScrollView while writing: the card fills whatever the
                // keyboard leaves behind, and the editor scrolls internally.
                if showWriting {
                    VStack(spacing: 12) {
                        if cashedIn {
                            rewardPanel
                                .frame(maxHeight: .infinity)
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                        } else {
                            writingCard
                                .crumpling(progress: holdProgress)
                                .frame(maxHeight: .infinity)

                            if readyToCash {
                                cashInButton
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Spacer(minLength: 0)
                }
            } else {
                ScrollView {
                    VStack(spacing: 28) {
                        header
                        sessionLauncher
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 28)
                    .frame(maxWidth: 900)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    private var desktopWritingLayout: some View {
        VStack(spacing: 0) {
            if isSessionActive && showProgress {
                compactProgressHeader
                    .frame(maxWidth: 900)
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity)
                    .background(ClearTheme.cream)
                    .shadow(color: ClearTheme.forest.opacity(0.08), radius: 10, y: 5)
                    .zIndex(1)
                    .transition(
                        .scale(scale: 0.90, anchor: .top)
                            .combined(with: .opacity)
                    )
            }

            ScrollView {
                VStack(spacing: 28) {
                    if !isSessionActive {
                        header
                    }

                    if isSessionActive {
                        if showWriting {
                            if cashedIn {
                                rewardPanel
                                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                            } else {
                                writingCard
                                    .crumpling(progress: holdProgress, travel: 300)
                                    .transition(
                                        .move(edge: .bottom)
                                            .combined(with: .opacity)
                                    )

                                if readyToCash {
                                    cashInButton
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                        }
                    } else {
                        sessionLauncher
                            .transition(
                                .scale(scale: 0.96)
                                    .combined(with: .opacity)
                            )
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, isSessionActive ? 18 : 28)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("DumpIt")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Brain Dump journal made easy")
                .font(.title3.weight(.medium))
                .foregroundStyle(ClearTheme.tealDark)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    /// Offered only when a session was interrupted — leaving on purpose still
    /// bins it.
    private func recoveryCard(_ draft: SessionDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.uturn.left.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ClearTheme.tealDark)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Unfinished dump")
                        .font(.headline.weight(.bold))
                    Text("\(draft.wordCount) words · \(draft.startedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(ClearTheme.muted)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button {
                    resumeDraft(draft)
                } label: {
                    Label("Pick it back up", systemImage: "play.fill")
                        .font(.subheadline.weight(.bold))
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(ClearTheme.teal)

                Button {
                    SessionStore.clearDraft()
                    withAnimation { recoveredDraft = nil }
                } label: {
                    Label("Bin it", systemImage: "trash")
                        .font(.subheadline.weight(.bold))
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .tint(ClearTheme.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: 420)
        .background(ClearTheme.mint.opacity(0.42), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// The three rules, stated before you start rather than discovered mid-dump.
    private var sessionRules: some View {
        VStack(alignment: .leading, spacing: 10) {
            rule("delete.backward.fill", "No backspace, no delete")
            rule("lock.fill", "No editing what you wrote")
            rule("timer", "Finish it in one sitting")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: 420)
        .background(ClearTheme.creamDeep.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func rule(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(ClearTheme.tealDark)
                .frame(width: 22)
            Text(text)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(ClearTheme.forest.opacity(0.85))
            Spacer(minLength: 0)
        }
    }

    /// Running tally of cleared sessions, shown on the home screen.
    private var clearMindTracker: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(ClearTheme.yellow.opacity(0.28))
                    .frame(width: 44, height: 44)
                Image(systemName: "bolt.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(ClearTheme.yellow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Clear mind")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ClearTheme.muted)
                Text("\(journal.totalPoints) points")
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(ClearTheme.tealDark)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(journal.sessionCount == 1 ? "session" : "sessions")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ClearTheme.muted)
                Text("\(journal.sessionCount)")
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(ClearTheme.tealDark)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 420)
        .background(ClearTheme.mint.opacity(0.32), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clear mind tracker: \(journal.totalPoints) points from \(journal.sessionCount) sessions")
    }

    private var sessionLauncher: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(ClearTheme.mint.opacity(0.4))
                    .frame(width: 176, height: 176)

                PipArtwork(size: 190)
                    .shadow(color: ClearTheme.forest.opacity(0.16), radius: 14, y: 8)
            }

            VStack(spacing: 8) {
                Text("Ready to dump your thoughts?")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Begin a private 500-word session and watch your mind get lighter.")
                    .font(.title3)
                    .foregroundStyle(ClearTheme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }

            if let recoveredDraft {
                recoveryCard(recoveredDraft)
            }

            sessionRules

            clearMindTracker

            Button(action: beginSession) {
                Label("Start a brain dump", systemImage: "play.fill")
            }
            .buttonStyle(ClearButtonStyle())
            .frame(maxWidth: 420)

            Button {
                showOnboarding = true
            } label: {
                Label("Check onboarding", systemImage: "questionmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(ClearTheme.tealDark)
            .frame(maxWidth: 420)
            .accessibilityHint("Replays the tour of how DumpIt works")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 38)
        .frame(maxWidth: .infinity)
        .clearCard(radius: 30)
    }

    /// Slim sticky header on both platforms: one line of status, the count,
    /// and a thin bar.
    private var compactProgressHeader: some View {
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(progressNudge)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ClearTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                Text("\(min(store.wordCount, SessionStore.goal))")
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(ClearTheme.tealDark)
                Text("/ \(SessionStore.goal)")
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(ClearTheme.muted)
            }

            GlowingClearProgressBar(
                value: store.progress,
                isActive: isEnteringSession || (store.progress > 0 && !store.hasReachedClearState),
                barHeight: isCompact ? 14 : 16
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .clearCard(radius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today’s Clear State")
    }

    private var writingCard: some View {
        VStack(alignment: .leading, spacing: isCompact ? 12 : 18) {
            HStack(spacing: 10) {
                Button {
                    if store.wordCount > 0 && !cashedIn {
                        confirmLeave = true
                    } else {
                        returnToLauncher()
                    }
                } label: {
                    Label("Home", systemImage: "chevron.left")
                        .font(.subheadline.weight(.bold))
                }
                .buttonStyle(.bordered)
                .tint(ClearTheme.tealDark)
                .accessibilityHint("Leaves this session. Unfinished writing is lost")

                Spacer(minLength: 4)

                Text(sessionStamp)
                    .font((isCompact ? Font.subheadline : .headline).weight(.bold))
                    .foregroundStyle(ClearTheme.tealDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 4)
                Button {
                    showOnboarding = true
                } label: {
                    Image(systemName: "questionmark")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Check onboarding")
            }

            Text(sessionPrompt)
                .font((isCompact ? Font.title2 : .largeTitle).weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            ZStack(alignment: .topLeading) {
                if store.releasedText.isEmpty && store.draft.isEmpty {
                    Text(placeholder)
                        .font(isCompact ? .body : .title2)
                        .foregroundStyle(ClearTheme.muted.opacity(0.7))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                InlineFadingTextEditor(
                    draft: $store.draft,
                    releasedText: store.releasedText,
                    shouldFocus: isWriting,
                    onBlockedEdit: { flashRule() }
                )
                .accessibilityHint("Older writing softens behind you while the newest words stay clear")
            }
            .frame(minHeight: isCompact ? 140 : 360, idealHeight: isCompact ? nil : 430)
            .frame(maxHeight: isCompact ? .infinity : nil)

            HStack {
                if let ruleNudge {
                    Label(ruleNudge, systemImage: "hand.raised.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ClearTheme.coral)
                        .transition(.opacity)
                }
                Spacer()
                Text("\(store.wordCount) words")
                    .font((isCompact ? Font.subheadline : .headline).monospacedDigit().weight(.bold))
                    .foregroundStyle(ClearTheme.tealDark)
            }
        }
        .padding(isCompact ? 16 : 24)
        .frame(maxHeight: isCompact ? .infinity : nil)
        .clearCard(radius: isCompact ? 24 : 28)
        .onTapGesture { isWriting = true }
    }

    /// Stamps the session with when it was written, matching the journal.
    private var sessionStamp: String {
        let day = isCompact
            ? sessionStart.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            : sessionStart.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        return "\(day) · \(sessionStart.formatted(date: .omitted, time: .shortened))"
    }

    /// iOS runs the tight layout; macOS keeps the roomier one.
    private var isCompact: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    /// Saves the finished session once, even though `hasReachedClearState`
    /// can fire again while the completion sheet is up.
    private func recordSession() {
        guard !didRecordSession else { return }
        let text = store.sessionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        didRecordSession = true
        journal.record(text: text, wordCount: store.wordCount, date: sessionStart)
        SessionStore.clearDraft()
        recoveredDraft = nil
    }

    // MARK: - Cash in

    private var banked: Int { journal.entries.first?.points ?? JournalStore.pointsPerSession }

    private var awards: [Award] {
        var list: [Award] = []

        if journal.sessionCount == 1 {
            list.append(Award(icon: "star.fill", title: "First dump", detail: "Your bin starts filling up"))
        }

        let streak = journal.currentStreak
        if let tier = BinTier.current(for: streak), tier.minStreak == streak {
            list.append(Award(
                icon: "trash.fill",
                title: "\(tier.name) unlocked",
                detail: "\(streak)-day streak — you earned a bigger bin"
            ))
        } else if [3, 7, 14, 30, 60, 100].contains(streak) {
            list.append(Award(icon: "flame.fill", title: "\(streak)-day streak", detail: "\(streak) days in a row cleared"))
        }

        if [25, 50, 100, 250, 500, 1000].contains(journal.totalPoints) {
            list.append(Award(icon: "trophy.fill", title: "\(journal.totalPoints) points", detail: "Milestone reached"))
        }

        if journal.entryCount(on: .now) >= 2 {
            list.append(Award(icon: "bolt.horizontal.fill", title: "Double dump", detail: "More than one session today"))
        }

        return list
    }

    /// Sits directly under the page you just wrote. Holding it screws that page
    /// up and drops it in the bin.
    private var cashInButton: some View {
        ZStack {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ClearTheme.tealDark.opacity(0.16))
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ClearTheme.teal)
                        .frame(width: proxy.size.width * holdProgress)
                }
            }

            Label(
                isHolding ? "Keep holding…" : "Hold to dump it",
                systemImage: isHolding ? "hourglass" : "hand.tap.fill"
            )
            .font(.headline.weight(.bold))
            .foregroundStyle(holdProgress > 0.55 ? .white : ClearTheme.tealDark)
        }
        .frame(height: 58)
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .scaleEffect(isHolding ? 0.97 : 1)
        .animation(.easeOut(duration: 0.15), value: isHolding)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isHolding, !cashedIn else { return }
                    beginHold()
                }
                .onEnded { _ in releaseHold() }
        )
        .accessibilityLabel("Hold to dump your 500 words into the bin")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { finishCashIn(instant: true) }
    }

    private var rewardPanel: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    ForEach(0..<14, id: \.self) { index in
                        let angle = Double(index) / 14 * 2 * .pi
                        Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "circle.fill")
                            .font(.system(size: index.isMultiple(of: 2) ? 15 : 7, weight: .bold))
                            .foregroundStyle(index.isMultiple(of: 3) ? ClearTheme.teal : ClearTheme.yellow)
                            .offset(
                                x: cos(angle) * (burst ? 108 : 20),
                                y: sin(angle) * (burst ? 108 : 20)
                            )
                            .opacity(burst ? 0 : 1)
                            .scaleEffect(burst ? 1.35 : 0.3)
                    }

                    Circle()
                        .fill(ClearTheme.yellow)
                        .frame(width: 116, height: 116)
                        .shadow(color: ClearTheme.yellow.opacity(0.45), radius: 24)

                    PipMascot(mood: .cheering, size: 92)
                }
                .frame(height: 140)

                VStack(spacing: 6) {
                    Text("Dumped.")
                        .font(.largeTitle.weight(.bold))
                    Text("+\(banked) clear mind points · \(journal.totalPoints) total")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(ClearTheme.tealDark)
                }

                ForEach(Array(awards.enumerated()), id: \.element.id) { index, award in
                    HStack(spacing: 12) {
                        Image(systemName: award.icon)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(ClearTheme.teal, in: Circle())

                        VStack(alignment: .leading, spacing: 1) {
                            Text(award.title)
                                .font(.headline.weight(.bold))
                            Text(award.detail)
                                .font(.subheadline)
                                .foregroundStyle(ClearTheme.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .clearCard(radius: 20)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.7).delay(Double(index) * 0.12),
                        value: cashedIn
                    )
                }

                HStack(spacing: 10) {
                    TrashCanIcon(isOpen: true, size: 26)
                        .foregroundStyle(ClearTheme.tealDark)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Tossed in your bin")
                            .font(.headline.weight(.bold))
                        Text(sessionStart.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.subheadline)
                            .foregroundStyle(ClearTheme.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(ClearTheme.mint.opacity(0.4), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(spacing: 10) {
                    Button(action: beginSession) {
                        Label("Start another session", systemImage: "play.fill")
                    }
                    .buttonStyle(ClearButtonStyle())

                    Button {
                        returnToLauncher()
                        router.tab = .dump
                    } label: {
                        Label("Open your bin", systemImage: "trash.fill")
                            .font(.subheadline.weight(.bold))
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(ClearTheme.tealDark)
                }
                .frame(maxWidth: 460)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }

    private func beginHold() {
        isHolding = true
        holdTask?.cancel()

        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        holdTask = Task { @MainActor in
            let tick = 1.0 / 60.0
            while !Task.isCancelled && holdProgress < 1 {
                try? await Task.sleep(for: .seconds(tick))
                guard !Task.isCancelled else { return }
                holdProgress = min(holdProgress + tick / 1.5, 1)
            }
            guard !Task.isCancelled else { return }
            finishCashIn(instant: false)
        }
    }

    private func releaseHold() {
        guard !cashedIn else { return }
        isHolding = false
        holdTask?.cancel()

        // Let go and the page smooths itself back out.
        holdTask = Task { @MainActor in
            while !Task.isCancelled && holdProgress > 0 {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                holdProgress = max(holdProgress - 0.035, 0)
            }
        }
    }

    private func finishCashIn(instant: Bool) {
        holdTask?.cancel()
        isHolding = false
        holdProgress = 1

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        withAnimation(.easeOut(duration: 0.75)) { burst = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { cashedIn = true }
    }

    /// Says why a keystroke was refused, then gets out of the way.
    private func flashRule() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
        ruleNudgeTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) {
            ruleNudge = ["No backspace — keep going.",
                         "No edits. Only forward.",
                         "What's written is written."].randomElement()
        }
        ruleNudgeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { ruleNudge = nil }
        }
    }

    private func resetCashIn() {
        holdTask?.cancel()
        ruleNudgeTask?.cancel()
        ruleNudge = nil
        readyToCash = false
        cashedIn = false
        isHolding = false
        holdProgress = 0
        burst = false
    }

    private func refreshSessionCopy() {
        sessionPrompt = WritingCopy.pick(from: WritingCopy.sessionPrompts, avoiding: sessionPrompt)
        placeholder = WritingCopy.pick(from: WritingCopy.placeholders, avoiding: placeholder)
        progressTier = .idle
        progressNudge = WritingCopy.pick(from: WritingCopy.nudges(for: .idle), avoiding: progressNudge)
    }

    /// The visible fade now trails the cursor continuously; this only locks
    /// paused writing into the released bucket so word counts stay stable.
    private func scheduleFade() {
        fadeTask?.cancel()

        fadeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5.5))
            guard !Task.isCancelled else { return }
            store.releaseDraft()
            store.persistDraft(startedAt: sessionStart)
        }
    }

    private func resumeDraft(_ draft: SessionDraft) {
        beginSession()
        store.resume(draft)
        sessionStart = draft.startedAt
        recoveredDraft = nil
    }

    private func beginSession() {
        fadeTask?.cancel()
        revealTask?.cancel()
        store.startFresh()
        didRecordSession = false
        resetCashIn()
        sessionStart = .now
        refreshSessionCopy()
        isWriting = false
        showProgress = false
        showWriting = false
        isEnteringSession = true

        withAnimation(.easeOut(duration: 0.18)) {
            isSessionActive = true
        }

        revealTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                showProgress = true
            }

            try? await Task.sleep(for: .milliseconds(190))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.62, dampingFraction: 0.78)) {
                showWriting = true
            }

            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            isEnteringSession = false
            isWriting = true
        }
    }

    private func returnToLauncher() {
        fadeTask?.cancel()
        revealTask?.cancel()
        isWriting = false

        withAnimation(.easeInOut(duration: 0.24)) {
            showWriting = false
            showProgress = false
            isSessionActive = false
        }

        store.startFresh()
        didRecordSession = false
        resetCashIn()
        refreshSessionCopy()
        isEnteringSession = false
    }
}

/// What the finish earned you, beyond the base points.
struct Award: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}
