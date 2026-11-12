import Foundation

/// A plain value copy of one diary entry. Forms edit it, and the totals and the
/// PDF export read it, so none of that logic depends on SwiftData or SwiftUI.
struct NoiseRecord: Equatable {
    var startedAt: Date
    var durationMinutes: Int = 15
    var noiseType: NoiseType = .music
    var noiseTypeOther: String = ""
    var source: NoiseSource = .nextDoor
    var sourceDetail: String = ""
    var effects: Set<NoiseEffect> = []
    var effectOther: String = ""
    var notes: String = ""
    var audioFileName: String?
    var recordingSeconds: Double = 0
    var averageLevel: Double?
    var peakLevel: Double?
    /// True when the entry was written after the event, without a recording.
    var isAddedLater: Bool = false
    var createdAt: Date = Date()

    var endedAt: Date {
        startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    var hasRecording: Bool { audioFileName != nil }

    var typeDescription: String {
        let other = noiseTypeOther.trimmingCharacters(in: .whitespacesAndNewlines)
        if noiseType == .other {
            return other.isEmpty ? NoiseType.other.title : other
        }
        return other.isEmpty ? noiseType.title : "\(noiseType.title): \(other)"
    }

    var sourceDescription: String {
        let detail = sourceDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? source.title : "\(source.title) (\(detail))"
    }

    /// Effects in a stable order, followed by anything typed in.
    var effectTitles: [String] {
        var titles = NoiseEffect.allCases.filter { effects.contains($0) }.map(\.title)
        let other = effectOther.trimmingCharacters(in: .whitespacesAndNewlines)
        if !other.isEmpty { titles.append(other) }
        return titles
    }

    var effectsDescription: String {
        let titles = effectTitles
        return titles.isEmpty ? "Not noted" : titles.joined(separator: ", ")
    }

    var trimmedNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension NoiseRecord {
    /// A record for noise happening now. The start time is the moment of the tap.
    static func live(startedAt: Date) -> NoiseRecord {
        var record = NoiseRecord(startedAt: startedAt)
        record.applyRememberedChoices()
        record.durationMinutes = 1
        record.createdAt = startedAt
        return record
    }

    /// A record for noise that already happened, written up after the event.
    static func addedLater(now: Date, calendar: Calendar = .current) -> NoiseRecord {
        let anHourAgo = now.addingTimeInterval(-3600)
        let minute = calendar.component(.minute, from: anHourAgo)
        let rounded = calendar.date(byAdding: .minute, value: -(minute % 5), to: anHourAgo) ?? anHourAgo
        var record = NoiseRecord(startedAt: rounded)
        record.applyRememberedChoices()
        record.isAddedLater = true
        record.createdAt = now
        return record
    }

    /// Most diaries are about one neighbour and one kind of noise, so the last
    /// choices are the best defaults for the next entry.
    mutating func applyRememberedChoices(defaults: UserDefaults = .standard) {
        if let raw = defaults.string(forKey: SettingsKeys.lastNoiseType), let type = NoiseType(rawValue: raw) {
            noiseType = type
        }
        if let raw = defaults.string(forKey: SettingsKeys.lastNoiseSource), let source = NoiseSource(rawValue: raw) {
            self.source = source
        }
        sourceDetail = defaults.string(forKey: SettingsKeys.lastSourceDetail) ?? ""
    }

    func rememberChoices(defaults: UserDefaults = .standard) {
        defaults.set(noiseType.rawValue, forKey: SettingsKeys.lastNoiseType)
        defaults.set(source.rawValue, forKey: SettingsKeys.lastNoiseSource)
        defaults.set(sourceDetail, forKey: SettingsKeys.lastSourceDetail)
    }
}

enum SettingsKeys {
    static let lockEnabled = "lockEnabled"
    static let lastNoiseType = "lastNoiseType"
    static let lastNoiseSource = "lastNoiseSource"
    static let lastSourceDetail = "lastSourceDetail"
    static let ownerName = "ownerName"
    static let ownerAddress = "ownerAddress"
    static let noiseAddress = "noiseAddress"
}
