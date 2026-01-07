import Foundation
import SwiftUI

// MARK: - History Entry Model
struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let promptName: String
    let promptID: UUID
    let originalText: String
    let transformedText: String

    init(promptName: String, promptID: UUID, originalText: String, transformedText: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.promptName = promptName
        self.promptID = promptID
        self.originalText = originalText
        self.transformedText = transformedText
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - History Manager
class HistoryManager: ObservableObject {
    @Published var entries: [HistoryEntry] = []

    private let saveKey = "QPhrase.History"
    private let maxEntries = 50

    init() {
        loadHistory()
    }

    func addEntry(promptName: String, promptID: UUID, originalText: String, transformedText: String) {
        let entry = HistoryEntry(
            promptName: promptName,
            promptID: promptID,
            originalText: originalText,
            transformedText: transformedText
        )

        entries.insert(entry, at: 0)

        // Trim to max entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        saveHistory()
    }

    func clearHistory() {
        entries.removeAll()
        saveHistory()
    }

    func deleteEntry(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        saveHistory()
    }

    private func saveHistory() {
        do {
            let encoded = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(encoded, forKey: saveKey)
        } catch {
            print("QPhrase: Failed to encode history: \(error.localizedDescription)")
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else {
            return
        }

        do {
            entries = try JSONDecoder().decode([HistoryEntry].self, from: data)
        } catch {
            print("QPhrase: Failed to decode history: \(error.localizedDescription)")
        }
    }
}
