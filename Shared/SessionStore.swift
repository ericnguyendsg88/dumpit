import Foundation
import SwiftUI

/// An in-progress session parked on disk, so a crash or a swipe-away does not
/// destroy writing you have not finished yet.
struct SessionDraft: Codable {
    var text: String
    var wordCount: Int
    var startedAt: Date
    var updatedAt: Date
}

@MainActor
final class SessionStore: ObservableObject {
    static let goal = 500

    @Published var draft = ""
    @Published private(set) var releasedWordCount = 0
    @Published private(set) var releasedText = ""

    var wordCount: Int {
        releasedWordCount + Self.countWords(draft)
    }

    /// Counts on whitespace *and* punctuation, so "don't stop — really" reads
    /// as four. Apostrophes stay inside a word; everything else breaks it.
    static func countWords(_ text: String) -> Int {
        text.split { character in
            character.isWhitespace
                || (character.isPunctuation && character != "'" && character != "’")
                || character.isMathSymbol
        }.count
    }

    /// Everything written this session, faded or not — what gets journaled.
    var sessionText: String {
        releasedText + draft
    }

    var progress: Double {
        min(Double(wordCount) / Double(Self.goal), 1)
    }

    var wordsRemaining: Int {
        max(Self.goal - wordCount, 0)
    }

    var hasReachedClearState: Bool {
        wordCount >= Self.goal
    }

    func releaseDraft() {
        let words = Self.countWords(draft)
        guard words > 0 else { return }
        releasedText += draft
        releasedWordCount += words
        draft = ""
    }

    func startFresh() {
        draft = ""
        releasedWordCount = 0
        releasedText = ""
    }

    // MARK: - Draft recovery

    private static var draftURL: URL {
        SharedStore.journalURL.deletingLastPathComponent().appendingPathComponent("draft.json")
    }

    /// Writes the session as it stands. Cheap enough to call on every pause.
    func persistDraft(startedAt: Date) {
        let text = sessionText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Self.clearDraft()
            return
        }

        let draft = SessionDraft(
            text: text,
            wordCount: wordCount,
            startedAt: startedAt,
            updatedAt: .now
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(draft) else { return }
        try? data.write(to: Self.draftURL, options: .atomic)
    }

    static func loadDraft() -> SessionDraft? {
        guard let data = try? Data(contentsOf: draftURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let draft = try? decoder.decode(SessionDraft.self, from: data) else { return nil }
        return draft.wordCount > 0 ? draft : nil
    }

    static func clearDraft() {
        try? FileManager.default.removeItem(at: draftURL)
    }

    /// Restores recovered writing as released text — still uneditable, exactly
    /// as it was when you left it.
    func resume(_ recovered: SessionDraft) {
        releasedText = recovered.text
        releasedWordCount = Self.countWords(recovered.text)
        draft = ""
    }
}
