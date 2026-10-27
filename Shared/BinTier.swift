import SwiftUI

/// Streak rewards: the longer you keep dumping, the bigger the bin you earn.
struct BinTier: Identifiable, Hashable {
    let id: Int
    let name: String
    let minStreak: Int
    /// Asset name of the illustration.
    let image: String
    /// Share of the badge frame this bin fills, so bigger tiers look bigger.
    let scale: CGFloat

    static let all: [BinTier] = [
        BinTier(id: 1, name: "Cup bin", minStreak: 1, image: "BinTier1", scale: 0.62),
        BinTier(id: 3, name: "Mesh basket", minStreak: 3, image: "BinTier2", scale: 0.70),
        BinTier(id: 7, name: "Swing top", minStreak: 7, image: "BinTier3", scale: 0.76),
        BinTier(id: 14, name: "Pedal bin", minStreak: 14, image: "BinTier4", scale: 0.82),
        BinTier(id: 30, name: "Dome bin", minStreak: 30, image: "BinTier5", scale: 0.86),
        BinTier(id: 60, name: "Wheelie bin", minStreak: 60, image: "BinTier6", scale: 0.92),
        BinTier(id: 100, name: "Dumpster", minStreak: 100, image: "BinTier7", scale: 0.96),
        BinTier(id: 365, name: "Industrial", minStreak: 365, image: "BinTier8", scale: 1.0)
    ]

    static func current(for streak: Int) -> BinTier? {
        all.last { streak >= $0.minStreak }
    }

    static func next(after streak: Int) -> BinTier? {
        all.first { streak < $0.minStreak }
    }

    var requirement: String {
        minStreak == 1 ? "1 day" : "\(minStreak) days"
    }
}

/// A tier's bin, sized by rank.
struct BinBadge: View {
    let tier: BinTier
    var frameSize: CGFloat = 64
    var isCurrent: Bool = false

    var body: some View {
        ZStack {
            if isCurrent {
                Circle()
                    .fill(ClearTheme.mint.opacity(0.5))
                    .frame(width: frameSize, height: frameSize)
            }

            Image(tier.image)
                .resizable()
                .scaledToFit()
                .frame(
                    width: frameSize * tier.scale,
                    height: frameSize * tier.scale
                )
        }
        .frame(width: frameSize, height: frameSize)
    }
}

/// The full ladder, with the earned tier called out.
struct BinTierStrip: View {
    let streak: Int
    /// While this is on, every tier renders as earned.
    var showAllUnlocked = true

    @State private var selected: BinTier?

    private var current: BinTier? { BinTier.current(for: streak) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bin tiers")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(ClearTheme.tealDark)
                Spacer()
                if let current {
                    Text("You: \(current.name)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ClearTheme.muted)
                } else if let next = BinTier.next(after: streak) {
                    Text("Next: \(next.name)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ClearTheme.muted)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(BinTier.all) { tier in
                        let earned = showAllUnlocked || streak >= tier.minStreak

                        Button {
                            selected = tier
                        } label: {
                            VStack(spacing: 6) {
                            BinBadge(
                                tier: tier,
                                frameSize: 64,
                                isCurrent: tier == current
                            )
                            .opacity(earned ? 1 : 0.28)
                            .saturation(earned ? 1 : 0)

                            Text(tier.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(earned ? ClearTheme.forest : ClearTheme.muted)
                                .lineLimit(1)
                            Text(tier.requirement)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(ClearTheme.muted)
                        }
                            .frame(width: 96)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(tier.name), \(tier.requirement) streak\(tier == current ? ", your current bin" : ""). Tap for a closer look")
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .clearCard(radius: 22)
        .sheet(item: $selected) { tier in
            BinTierDetail(tier: tier, streak: streak) { selected = nil }
        }
    }
}

/// A closer look at one bin.
struct BinTierDetail: View {
    let tier: BinTier
    let streak: Int
    let onClose: () -> Void

    private var isCurrent: Bool { BinTier.current(for: streak) == tier }
    private var isEarned: Bool { streak >= tier.minStreak }

    private var isCompact: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Button("Done", action: onClose)
                    .font(.headline.weight(.bold))
                    .buttonStyle(.bordered)
            }

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(ClearTheme.mint.opacity(isCurrent ? 0.55 : 0.28))
                    .frame(width: 250, height: 250)

                Image(tier.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 230, height: 230)
                    .shadow(color: ClearTheme.forest.opacity(0.18), radius: 18, y: 10)
            }

            VStack(spacing: 8) {
                Text(tier.name)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)

                Label("\(tier.requirement) streak", systemImage: "flame.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(ClearTheme.tealDark)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(ClearTheme.mint.opacity(0.5), in: Capsule())

                Text(status)
                    .font(.body)
                    .foregroundStyle(ClearTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(isCompact ? 22 : 30)
        .frame(
            minWidth: isCompact ? nil : 460,
            idealWidth: isCompact ? nil : 520,
            minHeight: isCompact ? nil : 560
        )
        .clearstateScreen()
    }

    private var status: String {
        if isCurrent {
            return "This is the bin you are carrying right now."
        }
        if isEarned {
            return "Earned. You have already been through this one."
        }
        let togo = tier.minStreak - streak
        return "\(togo) more day\(togo == 1 ? "" : "s") in a row and this one is yours."
    }
}
