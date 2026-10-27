import SwiftUI

/// Past sessions, newest first, grouped by day. Same view on both platforms.
struct HistoryView: View {
    @EnvironmentObject private var journal: JournalStore
    /// Nil when the view is a tab; set when it is presented as a sheet.
    var onClose: (() -> Void)?

    @State private var selected: JournalEntry?
    @State private var pendingDelete: JournalEntry?
    @State private var showOnboarding = false

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

            ScrollView {
                statsBoard
                    .padding(.horizontal, isCompact ? 18 : 24)
                    .padding(.bottom, 18)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)

                if journal.entries.isEmpty {
                    emptyState
                } else {
                    LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                        ForEach(journal.entriesByDay, id: \.day) { group in
                            Section {
                                // Loose scraps, not a tidy stack — these were
                                // thrown away.
                                VStack(spacing: 14) {
                                    ForEach(group.entries) { entry in
                                        row(for: entry)
                                    }
                                }
                            } header: {
                                Text(group.day)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(ClearTheme.tealDark)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .background(ClearTheme.cream)
                            }
                        }
                    }
                    .padding(.horizontal, isCompact ? 18 : 24)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(
            minWidth: isCompact || onClose == nil ? nil : 560,
            idealWidth: isCompact || onClose == nil ? nil : 640,
            minHeight: isCompact || onClose == nil ? nil : 560,
            idealHeight: isCompact || onClose == nil ? nil : 680
        )
        .clearstateScreen()
        .sheet(item: $selected) { entry in
            EntryDetailView(entry: entry) { selected = nil }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView { showOnboarding = false }
        }
        .alert("Delete this entry?", isPresented: .constant(pendingDelete != nil)) {
            Button("Delete", role: .destructive) {
                if let pendingDelete { journal.delete(pendingDelete) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            if let pendingDelete {
                Text("\(pendingDelete.shortStamp) · \(pendingDelete.wordCount) words. This can’t be undone.")
            }
        }
    }

    /// Points and stats live on top of the journal now — one screen, not two.
    private var statsBoard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(ClearTheme.yellow.opacity(0.28))
                        .frame(width: 56, height: 56)
                    Image(systemName: "bolt.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(ClearTheme.yellow)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(journal.totalPoints)")
                        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(ClearTheme.tealDark)
                    Text("clear mind points")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ClearTheme.muted)
                }

                Spacer()

                Button {
                    showOnboarding = true
                } label: {
                    Image(systemName: "questionmark")
                        .font(.headline.weight(.bold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(ClearTheme.tealDark)
                .accessibilityLabel("How DumpIt works")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .clearCard(radius: 24)

            weekStrip

            BinTierStrip(streak: journal.currentStreak)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
                spacing: 10
            ) {
                stat(value: "\(journal.sessionCount)", label: journal.sessionCount == 1 ? "session" : "sessions", icon: "checkmark.seal.fill")
                stat(value: journal.totalWords.formatted(), label: "words unloaded", icon: "text.alignleft")
            }
        }
    }

    /// Seven days of the current week, filled in for every day you cleared.
    private var weekStrip: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This week")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(ClearTheme.tealDark)
                Spacer()
                Label(
                    "\(journal.currentStreak) day\(journal.currentStreak == 1 ? "" : "s") in a row",
                    systemImage: "flame.fill"
                )
                .font(.subheadline.weight(.bold))
                .foregroundStyle(journal.currentStreak > 0 ? ClearTheme.coral : ClearTheme.muted)
            }

            HStack(spacing: 6) {
                ForEach(days, id: \.self) { day in
                    dayCell(day, today: today)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .clearCard(radius: 22)
    }

    private func dayCell(_ day: Date, today: Date) -> some View {
        let calendar = Calendar.current
        let sessions = journal.entryCount(on: day)
        let cleared = sessions > 0
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let isFuture = day > today

        return VStack(spacing: 7) {
            Text(day.formatted(.dateTime.weekday(.narrow)))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(ClearTheme.muted)

            ZStack {
                Circle()
                    .fill(
                        cleared
                            ? ClearTheme.teal
                            : ClearTheme.creamDeep.opacity(isFuture ? 0.45 : 0.9)
                    )

                if isToday {
                    Circle()
                        .stroke(ClearTheme.tealDark, lineWidth: 2.5)
                }

                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(
                        cleared
                            ? .white
                            : (isFuture ? ClearTheme.muted.opacity(0.5) : ClearTheme.muted)
                    )
            }
            .frame(height: 40)

            // A dot per session, so a double-unload day still reads as bigger.
            HStack(spacing: 2) {
                if cleared {
                    ForEach(0..<min(sessions, 3), id: \.self) { _ in
                        Circle()
                            .fill(ClearTheme.teal)
                            .frame(width: 4, height: 4)
                    }
                } else {
                    Circle().fill(.clear).frame(width: 4, height: 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(day.formatted(.dateTime.weekday(.wide).day().month(.wide))): \(cleared ? "\(sessions) session\(sessions == 1 ? "" : "s")" : "nothing yet")"
        )
    }

    private func stat(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(ClearTheme.tealDark)
                .frame(width: 32, height: 32)
                .background(ClearTheme.mint.opacity(0.5), in: Circle())

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(ClearTheme.forest)
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ClearTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clearCard(radius: 20)
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your bin")
                    .font(.largeTitle.weight(.bold))
                Text(summary)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ClearTheme.muted)
            }
            Spacer()
            if let onClose {
                Button("Done", action: onClose)
                    .font(.headline.weight(.bold))
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, isCompact ? 18 : 24)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var summary: String {
        let sessions = journal.sessionCount
        let plural = sessions == 1 ? "session" : "sessions"
        return "\(sessions) \(plural) · \(journal.totalPoints) points"
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            TrashCanIcon(isOpen: true, size: 54)
                .foregroundStyle(ClearTheme.teal.opacity(0.45))
            Text("The bin is empty")
                .font(.title3.weight(.bold))
            Text("Finish a 500-word dump and it lands in here, stamped with the date.")
                .font(.subheadline)
                .foregroundStyle(ClearTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(.top, 26)
        .frame(maxWidth: .infinity)
    }

    private func row(for entry: JournalEntry) -> some View {
        let seed = abs(entry.id.hashValue % 997)
        let tilt = Double((seed % 5) - 2) * 0.55

        return Button {
            selected = entry
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(entry.timeStamp)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ClearTheme.tealDark)
                    Text("·")
                        .foregroundStyle(ClearTheme.muted)
                    Text("\(entry.wordCount) words")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ClearTheme.muted)
                    Spacer()
                    Text("+\(entry.points)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ClearTheme.tealDark)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(ClearTheme.mint.opacity(0.55), in: Capsule())
                }

                Text(entry.preview)
                    .font(.callout)
                    .lineSpacing(3)
                    .foregroundStyle(ClearTheme.forest.opacity(0.78))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { ScrapPaperSurface(seed: seed) }
            .rotationEffect(.degrees(tilt))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive) { pendingDelete = entry }
        }
    }
}

private struct EntryDetailView: View {
    let entry: JournalEntry
    let onClose: () -> Void

    private var isCompact: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.dayStamp)
                        .font(.title2.weight(.bold))
                    Text("\(entry.timeStamp) · \(entry.wordCount) words · +\(entry.points) points")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ClearTheme.muted)
                }
                Spacer()
                Button("Done", action: onClose)
                    .font(.headline.weight(.bold))
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, isCompact ? 18 : 24)
            .padding(.top, 18)
            .padding(.bottom, 14)

            ScrollView {
                Text(entry.text)
                    .font(.body)
                    .lineSpacing(7)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .background {
                        ScrapPaperSurface(seed: abs(entry.id.hashValue % 997), heavy: true)
                    }
                    .rotationEffect(.degrees(-0.4))
                    .padding(.horizontal, isCompact ? 18 : 24)
                    .padding(.bottom, 24)
            }
        }
        .frame(
            minWidth: isCompact ? nil : 520,
            idealWidth: isCompact ? nil : 620,
            minHeight: isCompact ? nil : 520,
            idealHeight: isCompact ? nil : 640
        )
        .clearstateScreen()
    }
}
