import Foundation
import SwiftUI

// MARK: - Transformation Record
struct TransformationRecord: Identifiable {
    let id = UUID()
    let promptName: String
    let promptIcon: String
    let originalText: String
    let transformedText: String
    let timestamp: Date

    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours) hr ago"
        }
    }

    var previewText: String {
        let maxLength = 30
        let original = originalText.prefix(maxLength)
        let transformed = transformedText.prefix(maxLength)
        let originalSuffix = originalText.count > maxLength ? "..." : ""
        let transformedSuffix = transformedText.count > maxLength ? "..." : ""
        return "\"\(original)\(originalSuffix)\" → \"\(transformed)\(transformedSuffix)\""
    }
}

// MARK: - Transformation History Manager
class TransformationHistory: ObservableObject {
    static let shared = TransformationHistory()

    @Published var records: [TransformationRecord] = []
    @Published var lastUndoResult: UndoResult?

    private let maxRecords = 10

    enum UndoResult {
        case success
        case failure(String)
    }

    private init() {}

    func addRecord(promptName: String, promptIcon: String, original: String, transformed: String) {
        let record = TransformationRecord(
            promptName: promptName,
            promptIcon: promptIcon,
            originalText: original,
            transformedText: transformed,
            timestamp: Date()
        )

        DispatchQueue.main.async {
            self.records.insert(record, at: 0)
            if self.records.count > self.maxRecords {
                self.records.removeLast()
            }
        }
    }

    func clearHistory() {
        records.removeAll()
    }

    var mostRecent: TransformationRecord? {
        records.first
    }

    var recentRecords: [TransformationRecord] {
        Array(records.prefix(5))
    }
}

// MARK: - Notification for History Updates
extension Notification.Name {
    static let transformationCompleted = Notification.Name("transformationCompleted")
    static let undoRequested = Notification.Name("undoRequested")
}
