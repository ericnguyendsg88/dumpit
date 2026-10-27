import SwiftUI
import WidgetKit

struct DumpEntry: TimelineEntry {
    let date: Date
    let snapshot: JournalSnapshot
}

struct DumpProvider: TimelineProvider {
    func placeholder(in context: Context) -> DumpEntry {
        DumpEntry(
            date: .now,
            snapshot: JournalSnapshot(
                streak: 3,
                dumpedToday: false,
                totalPoints: 15,
                sessionCount: 3,
                tierName: "Mesh basket"
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DumpEntry) -> Void) {
        completion(DumpEntry(date: .now, snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DumpEntry>) -> Void) {
        let entry = DumpEntry(date: .now, snapshot: .load())
        // Refresh at midnight: "dumped today" and the streak both roll over.
        let midnight = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? Date.now.addingTimeInterval(3600)

        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

struct DumpWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DumpEntry

    private var snapshot: JournalSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(inlineText)

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: snapshot.dumpedToday ? "trash.fill" : "trash")
                        .font(.system(size: 13, weight: .bold))
                    Text("\(snapshot.streak)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("day")
                        .font(.system(size: 9, weight: .semibold))
                        .opacity(0.7)
                }
            }
            .widgetURL(URL(string: "dumpit://write"))

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: snapshot.dumpedToday ? "checkmark.circle.fill" : "trash")
                        .font(.system(size: 12, weight: .bold))
                    Text("DumpIt")
                        .font(.headline.weight(.bold))
                }

                Text(headline)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(subline)
                    .font(.caption)
                    .opacity(0.75)
                    .lineLimit(1)
            }
            .widgetURL(URL(string: "dumpit://write"))

        default:
            VStack(spacing: 6) {
                Image(systemName: "trash.fill")
                    .font(.title2.weight(.bold))
                Text("\(snapshot.streak) day streak")
                    .font(.headline.weight(.bold))
                Text(headline)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .widgetURL(URL(string: "dumpit://write"))
        }
    }

    private var inlineText: String {
        snapshot.dumpedToday
            ? "Dumped · \(snapshot.streak)d streak"
            : "Nothing dumped today"
    }

    private var headline: String {
        snapshot.dumpedToday ? "Head cleared today" : "Your head is filling up"
    }

    private var subline: String {
        if let tier = snapshot.tierName {
            return "\(snapshot.streak) day streak · \(tier)"
        }
        return "Start a streak — one dump today"
    }
}

struct DumpItWidget: Widget {
    let kind = "DumpItWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DumpProvider()) { entry in
            DumpWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("DumpIt streak")
        .description("Your dump streak, and whether today's head is still full.")
        .supportedFamilies([
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
            .systemSmall
        ])
    }
}

@main
struct DumpItWidgetBundle: WidgetBundle {
    var body: some Widget {
        DumpItWidget()
    }
}
