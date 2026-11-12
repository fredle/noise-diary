import Foundation

/// Builds the files handed to the share sheet: one PDF diary sheet plus,
/// optionally, the audio clip for each entry, named to match the PDF.
enum ExportBuilder {
    struct Output {
        let pdf: URL
        let audio: [URL]
        var all: [URL] { [pdf] + audio }
    }

    enum ExportError: LocalizedError {
        case noEntries

        var errorDescription: String? {
            switch self {
            case .noEntries: return "There are no entries between those dates."
            }
        }
    }

    /// Records whose start falls on or between the two days, oldest first.
    static func records(_ records: [NoiseRecord], from firstDay: Date, to lastDay: Date, calendar: Calendar = .current) -> [NoiseRecord] {
        let start = calendar.startOfDay(for: min(firstDay, lastDay))
        let lastStart = calendar.startOfDay(for: max(firstDay, lastDay))
        let end = calendar.date(byAdding: .day, value: 1, to: lastStart) ?? lastStart
        return records
            .filter { $0.startedAt >= start && $0.startedAt < end }
            .sorted { $0.startedAt < $1.startedAt }
    }

    /// "Entry 03 - 2026-11-10 2314.m4a". The number matches the PDF's No. column.
    static func audioFileName(index: Int, record: NoiseRecord, total: Int, calendar: Calendar = .current) -> String {
        let digits = max(2, String(total).count)
        let number = String(format: "%0\(digits)d", index + 1)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: record.startedAt)
        let stamp = String(
            format: "%04d-%02d-%02d %02d%02d",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0
        )
        return "Entry \(number) - \(stamp).m4a"
    }

    static func pdfFileName(from firstDay: Date, to lastDay: Date) -> String {
        let style = Date.FormatStyle().day().month(.abbreviated).year()
        let first = firstDay.formatted(style)
        let last = lastDay.formatted(style)
        let name = "Noise diary \(first) to \(last).pdf"
        return name.replacingOccurrences(of: "/", with: "-")
    }

    static func build(
        records allRecords: [NoiseRecord],
        from firstDay: Date,
        to lastDay: Date,
        owner: DiaryOwnerDetails,
        includeAudio: Bool,
        now: Date = Date()
    ) throws -> Output {
        let selected = Self.records(allRecords, from: firstDay, to: lastDay)
        guard !selected.isEmpty else { throw ExportError.noEntries }

        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: "Exports", directoryHint: .isDirectory)
        // Only the latest export is kept; older ones are cleared each time.
        try? fileManager.removeItem(at: root)
        let folder = root.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        var audioNames: [String?] = []
        var audioURLs: [URL] = []
        for (index, record) in selected.enumerated() {
            guard includeAudio, let stored = record.audioFileName, RecordingStore.exists(stored) else {
                audioNames.append(nil)
                continue
            }
            let name = Self.audioFileName(index: index, record: record, total: selected.count)
            let destination = folder.appending(path: name, directoryHint: .notDirectory)
            try fileManager.copyItem(at: RecordingStore.url(for: stored), to: destination)
            audioNames.append(name)
            audioURLs.append(destination)
        }

        let renderer = DiaryPDFRenderer(
            records: selected,
            audioNames: audioNames,
            firstDay: min(firstDay, lastDay),
            lastDay: max(firstDay, lastDay),
            owner: owner,
            generatedAt: now
        )
        let pdfURL = folder.appending(path: Self.pdfFileName(from: min(firstDay, lastDay), to: max(firstDay, lastDay)), directoryHint: .notDirectory)
        try renderer.render().write(to: pdfURL, options: .atomic)

        return Output(pdf: pdfURL, audio: audioURLs)
    }
}
