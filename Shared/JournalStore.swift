import Foundation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Container shared between the app and its widget.
enum SharedStore {
    static let appGroup = "group.com.ericdev.unload"

    static var journalURL: URL {
        storeDirectory.appendingPathComponent("journal.json")
    }

    /// Where the app keeps its data.
    ///
    /// The app group is iOS-only: that is the sole reason it exists (the
    /// widget). On macOS `containerURL` hands back a Group Containers path
    /// even with no entitlement, and that directory does not exist — writing
    /// to it silently fails and the bin reads empty.
    static var storeDirectory: URL {
        let manager = FileManager.default

        #if os(iOS)
        if let shared = manager.containerURL(forSecurityApplicationGroupIdentifier: appGroup),
           ensureDirectory(shared) {
            return shared
        }
        #endif

        let base = manager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL.temporaryDirectory
        let folder = base.appendingPathComponent("Unload", isDirectory: true)
        _ = ensureDirectory(folder)
        return folder
    }

    @discardableResult
    private static func ensureDirectory(_ url: URL) -> Bool {
        let manager = FileManager.default
        var isDirectory: ObjCBool = false
        if manager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        do {
            try manager.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }

    /// Entries decoded straight off disk — safe to call from a widget timeline.
    static func loadEntries(from url: URL? = nil) -> [JournalEntry] {
        let target = url ?? journalURL
        guard let data = try? Data(contentsOf: target) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let stored = try? decoder.decode([JournalEntry].self, from: data) else {
            // Park the unreadable file rather than let the next save flatten it.
            let quarantine = target
                .deletingLastPathComponent()
                .appendingPathComponent("journal.unreadable.json")
            try? FileManager.default.removeItem(at: quarantine)
            try? FileManager.default.moveItem(at: target, to: quarantine)
            return []
        }
        return stored.sorted { $0.date > $1.date }
    }
}

/// What the lock screen needs to know, computed without touching the main actor.
struct JournalSnapshot {
    var streak = 0
    var dumpedToday = false
    var totalPoints = 0
    var sessionCount = 0
    var tierName: String?

    static func load() -> JournalSnapshot {
        let entries = SharedStore.loadEntries()
        let calendar = Calendar.current
        let days = Set(entries.map { calendar.startOfDay(for: $0.date) })

        var streak = 0
        var cursor = calendar.startOfDay(for: .now)
        if !days.contains(cursor) {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
               days.contains(yesterday) {
                cursor = yesterday
            } else {
                cursor = .distantFuture
            }
        }
        if cursor != .distantFuture {
            while days.contains(cursor) {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previous
            }
        }

        return JournalSnapshot(
            streak: streak,
            dumpedToday: days.contains(calendar.startOfDay(for: .now)),
            totalPoints: entries.reduce(0) { $0 + $1.points },
            sessionCount: entries.count,
            tierName: BinTier.current(for: streak)?.name
        )
    }
}

struct JournalEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let text: String
    let wordCount: Int
    let points: Int

    init(id: UUID = UUID(), date: Date = .now, text: String, wordCount: Int, points: Int) {
        self.id = id
        self.date = date
        self.text = text
        self.wordCount = wordCount
        self.points = points
    }

    var dayStamp: String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    var timeStamp: String {
        date.formatted(date: .omitted, time: .shortened)
    }

    var shortStamp: String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        return trimmed.count <= 180 ? trimmed : String(trimmed.prefix(180)) + "…"
    }
}

/// Finished sessions, kept on disk so the history survives relaunches.
@MainActor
final class JournalStore: ObservableObject {
    static let pointsPerSession = 5

    @Published private(set) var entries: [JournalEntry] = []

    private let fileURL: URL

    var totalPoints: Int {
        entries.reduce(0) { $0 + $1.points }
    }

    var sessionCount: Int {
        entries.count
    }

    var totalWords: Int {
        entries.reduce(0) { $0 + $1.wordCount }
    }

    func entryCount(on day: Date) -> Int {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }.count
    }

    /// Consecutive days ending today (or yesterday, if today is still empty).
    var currentStreak: Int {
        let calendar = Calendar.current
        let days = Set(entries.map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: .now)
        if !days.contains(cursor) {
            guard
                let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                days.contains(yesterday)
            else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? SharedStore.journalURL
        Self.migrateLegacyStoreIfNeeded(to: self.fileURL)
        load()
    }

    /// Moves entries written before the app group existed into the shared file.
    private static func migrateLegacyStoreIfNeeded(to url: URL) {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: url.path) else { return }
        guard let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let legacy = base
            .appendingPathComponent("Unload", isDirectory: true)
            .appendingPathComponent("journal.json")
        guard legacy != url, manager.fileExists(atPath: legacy.path) else { return }
        try? manager.copyItem(at: legacy, to: url)
    }

    @discardableResult
    func record(text: String, wordCount: Int, date: Date = .now) -> JournalEntry {
        let entry = JournalEntry(
            date: date,
            text: text,
            wordCount: wordCount,
            points: Self.pointsPerSession
        )
        entries.insert(entry, at: 0)
        save()
        return entry
    }

    func delete(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func deleteAll() {
        entries.removeAll()
        save()
    }

    /// Newest first, bucketed by calendar day for the sectioned history list.
    var entriesByDay: [(day: String, entries: [JournalEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }
        return groups
            .sorted { $0.key > $1.key }
            .map { key, value in
                (day: Self.dayLabel(for: key), entries: value.sorted { $0.date > $1.date })
            }
    }

    private static func dayLabel(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    private func load() {
        entries = SharedStore.loadEntries(from: fileURL)
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)

        #if canImport(WidgetKit) && os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
