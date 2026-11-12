import Foundation
import SwiftData

/// One diary entry as stored on the phone. Enums are stored as raw strings so
/// that adding a case later never breaks existing data.
@Model
final class NoiseEntry {
    var startedAt: Date = Date()
    var durationMinutes: Int = 15
    var noiseTypeRaw: String = NoiseType.music.rawValue
    var noiseTypeOther: String = ""
    var sourceRaw: String = NoiseSource.nextDoor.rawValue
    var sourceDetail: String = ""
    var effectsRaw: String = ""
    var effectOther: String = ""
    var notes: String = ""
    var audioFileName: String?
    var recordingSeconds: Double = 0
    var averageLevel: Double?
    var peakLevel: Double?
    var isAddedLater: Bool = false
    var createdAt: Date = Date()

    init(record: NoiseRecord) {
        self.startedAt = record.startedAt
        self.durationMinutes = max(1, record.durationMinutes)
        self.noiseTypeRaw = record.noiseType.rawValue
        self.noiseTypeOther = record.noiseTypeOther
        self.sourceRaw = record.source.rawValue
        self.sourceDetail = record.sourceDetail
        self.effectsRaw = NoiseEntry.encode(record.effects)
        self.effectOther = record.effectOther
        self.notes = record.notes
        self.audioFileName = record.audioFileName
        self.recordingSeconds = record.recordingSeconds
        self.averageLevel = record.averageLevel
        self.peakLevel = record.peakLevel
        self.isAddedLater = record.isAddedLater
        self.createdAt = record.createdAt
    }

    static func encode(_ effects: Set<NoiseEffect>) -> String {
        NoiseEffect.allCases
            .filter { effects.contains($0) }
            .map(\.rawValue)
            .joined(separator: ",")
    }

    var noiseType: NoiseType {
        NoiseType(rawValue: noiseTypeRaw) ?? .other
    }

    var record: NoiseRecord {
        let effectSet = Set(effectsRaw.split(separator: ",").compactMap { NoiseEffect(rawValue: String($0)) })
        return NoiseRecord(
            startedAt: startedAt,
            durationMinutes: durationMinutes,
            noiseType: noiseType,
            noiseTypeOther: noiseTypeOther,
            source: NoiseSource(rawValue: sourceRaw) ?? .unsure,
            sourceDetail: sourceDetail,
            effects: effectSet,
            effectOther: effectOther,
            notes: notes,
            audioFileName: audioFileName,
            recordingSeconds: recordingSeconds,
            averageLevel: averageLevel,
            peakLevel: peakLevel,
            isAddedLater: isAddedLater,
            createdAt: createdAt
        )
    }

    func update(from record: NoiseRecord) {
        startedAt = record.startedAt
        durationMinutes = max(1, record.durationMinutes)
        noiseTypeRaw = record.noiseType.rawValue
        noiseTypeOther = record.noiseTypeOther
        sourceRaw = record.source.rawValue
        sourceDetail = record.sourceDetail
        effectsRaw = NoiseEntry.encode(record.effects)
        effectOther = record.effectOther
        notes = record.notes
        audioFileName = record.audioFileName
        recordingSeconds = record.recordingSeconds
        averageLevel = record.averageLevel
        peakLevel = record.peakLevel
        isAddedLater = record.isAddedLater
    }
}
