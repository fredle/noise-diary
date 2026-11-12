import UIKit

/// Details printed at the top of the diary sheet. Blank fields print as lines
/// to fill in by hand.
struct DiaryOwnerDetails {
    var name: String = ""
    var address: String = ""
    var noiseAddress: String = ""
}

/// Draws the diary as an A4 landscape table laid out like a council noise diary
/// sheet: date, time started, time finished, type of noise, where it came from,
/// how it affected you, plus the recording that goes with each entry.
struct DiaryPDFRenderer {
    /// Records in the order they should be printed (oldest first).
    let records: [NoiseRecord]
    /// The exported audio file name for each record, or nil. Same order as `records`.
    let audioNames: [String?]
    let firstDay: Date
    let lastDay: Date
    let owner: DiaryOwnerDetails
    let generatedAt: Date
    var calendar: Calendar = .current

    private let pageRect = CGRect(x: 0, y: 0, width: 841.89, height: 595.28)
    private let margin: CGFloat = 32
    private let footerHeight: CGFloat = 30
    private let padding: CGFloat = 4

    private struct Row {
        let cells: [NSAttributedString]
        let height: CGFloat
    }

    // MARK: - Text styles

    private var bodyFont: UIFont { UIFont.systemFont(ofSize: 8.5) }
    private var boldFont: UIFont { UIFont.boldSystemFont(ofSize: 8.5) }

    private func text(_ string: String, font: UIFont, color: UIColor = .black) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
    }

    /// A cell whose first line is bold and the rest regular.
    private func cell(_ lead: String, _ rest: String? = nil) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text(lead, font: boldFont))
        if let rest, !rest.isEmpty {
            result.append(text("\n" + rest, font: bodyFont))
        }
        return result
    }

    private func plain(_ string: String) -> NSAttributedString {
        text(string, font: bodyFont)
    }

    private func height(of string: NSAttributedString, width: CGFloat) -> CGFloat {
        let rect = string.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(rect.height)
    }

    private func draw(_ string: NSAttributedString, in rect: CGRect) {
        string.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }

    // MARK: - Columns

    private var columnTitles: [String] {
        ["No.", "Date", "Time started", "Time finished", "Type of noise and what happened",
         "Where it came from", "How it affected you", "Recording"]
    }

    private var columnWidths: [CGFloat] {
        let fixed: [CGFloat] = [24, 64, 46, 56, 170, 112, 146]
        let usable = pageRect.width - margin * 2
        return fixed + [usable - fixed.reduce(0, +)]
    }

    // MARK: - Content

    private func formatter(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    private func makeRows() -> [Row] {
        let weekday = formatter("EEE")
        let day = formatter("d MMM yyyy")
        let time = formatter("HH:mm")
        let stamp = formatter("d MMM HH:mm")
        let widths = columnWidths

        return records.enumerated().map { (index, record) -> Row in
            let ended = record.endedAt
            var finished = time.string(from: ended)
            if !calendar.isDate(ended, inSameDayAs: record.startedAt) {
                finished += " (next day)"
            }

            let typeCell = cell(record.typeDescription, record.trimmedNotes.isEmpty ? nil : record.trimmedNotes)

            var evidence: [String] = []
            if index < audioNames.count, let name = audioNames[index] {
                evidence.append("File: \(name)")
                evidence.append("Clip length: \(DiaryFormat.clipLength(seconds: record.recordingSeconds))")
                if let average = record.averageLevel, let peak = record.peakLevel {
                    evidence.append("Relative level: average \(DiaryFormat.level(average)), peak \(DiaryFormat.level(peak)) out of 100")
                }
            } else if record.hasRecording {
                evidence.append("Recorded on phone (audio not included in this export)")
            } else {
                evidence.append("No recording")
            }
            if record.isAddedLater {
                evidence.append("Written after the event, on \(stamp.string(from: record.createdAt))")
            }

            let cells: [NSAttributedString] = [
                plain("\(index + 1)"),
                cell(weekday.string(from: record.startedAt), day.string(from: record.startedAt)),
                cell(time.string(from: record.startedAt)),
                cell(finished, DiaryFormat.duration(minutes: record.durationMinutes)),
                typeCell,
                plain(record.sourceDescription),
                plain(record.effectsDescription),
                plain(evidence.joined(separator: "\n")),
            ]
            let tallest = zip(cells, widths)
                .map { height(of: $0, width: $1 - padding * 2) }
                .max() ?? 0
            return Row(cells: cells, height: tallest + padding * 2)
        }
    }

    private func headerLines() -> [NSAttributedString] {
        let blank = "______________________________________"
        func line(_ label: String, _ value: String) -> NSAttributedString {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = NSMutableAttributedString(attributedString: text("\(label): ", font: boldFont))
            result.append(text(trimmed.isEmpty ? blank : trimmed, font: UIFont.systemFont(ofSize: 9)))
            return result
        }
        let summary = DiarySummary(records: records, calendar: calendar)
        let day = formatter("EEE d MMM yyyy")
        let period = "\(day.string(from: firstDay)) to \(day.string(from: lastDay))"
        let totals = "\(DiaryFormat.entryCount(summary.entryCount)), "
            + "\(DiaryFormat.duration(minutes: summary.totalMinutes)) in total, "
            + "on \(summary.daysWithNoise) \(summary.daysWithNoise == 1 ? "day" : "days"); "
            + "\(summary.nightCount) at night (23:00–07:00)"
        return [
            line("Your name", owner.name),
            line("Your address", owner.address),
            line("Address the noise comes from", owner.noiseAddress),
            line("Period covered", period),
            line("Summary", totals),
        ]
    }

    private func declaration() -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text(
            "I confirm that this diary is a true record of the noise I experienced.\n",
            font: boldFont
        ))
        result.append(text(
            "\nSigned ____________________________________        Date ____________________",
            font: UIFont.systemFont(ofSize: 10)
        ))
        return result
    }

    // MARK: - Rendering

    func render() -> Data {
        let rows = makeRows()
        let widths = columnWidths
        let usableWidth = pageRect.width - margin * 2
        let bottom = pageRect.height - margin - footerHeight

        let titleText = text("Noise diary", font: UIFont.boldSystemFont(ofSize: 20))
        let titleHeight = height(of: titleText, width: usableWidth)
        let lines = headerLines()
        let lineHeights = lines.map { height(of: $0, width: usableWidth) }
        let headerHeight = titleHeight + 8 + lineHeights.reduce(0) { $0 + $1 + 3 } + 10

        let headerCells = columnTitles.map { text($0, font: boldFont) }
        let tableHeaderHeight = (zip(headerCells, widths)
            .map { height(of: $0, width: $1 - padding * 2) }
            .max() ?? 0) + padding * 2

        let emptyText = plain("No entries in this period.")
        let emptyHeight = height(of: emptyText, width: usableWidth) + padding * 4

        // Work out which rows go on which page.
        var pages: [[Int]] = [[]]
        var y = margin + headerHeight + tableHeaderHeight
        for (index, row) in rows.enumerated() {
            if y + row.height > bottom, !(pages.last ?? []).isEmpty {
                pages.append([])
                y = margin + tableHeaderHeight
            }
            pages[pages.count - 1].append(index)
            y += row.height
        }
        if rows.isEmpty { y += emptyHeight }

        let declarationText = declaration()
        let declarationHeight = height(of: declarationText, width: usableWidth)
        let declarationOnOwnPage = y + 18 + declarationHeight > bottom
        let pageCount = pages.count + (declarationOnOwnPage ? 1 : 0)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Noise diary",
            kCGPDFContextCreator as String: "Noise Diary",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            var pageNumber = 0

            for (pageIndex, rowIndexes) in pages.enumerated() {
                context.beginPage()
                pageNumber += 1
                var y = margin

                if pageIndex == 0 {
                    draw(titleText, in: CGRect(x: margin, y: y, width: usableWidth, height: titleHeight))
                    y += titleHeight + 8
                    for (line, lineHeight) in zip(lines, lineHeights) {
                        draw(line, in: CGRect(x: margin, y: y, width: usableWidth, height: lineHeight))
                        y += lineHeight + 3
                    }
                    y += 10
                }

                drawRow(cells: headerCells, widths: widths, y: y, height: tableHeaderHeight, shaded: true)
                y += tableHeaderHeight

                for index in rowIndexes {
                    let row = rows[index]
                    drawRow(cells: row.cells, widths: widths, y: y, height: row.height, shaded: false)
                    y += row.height
                }

                if rows.isEmpty {
                    let rect = CGRect(x: margin, y: y, width: usableWidth, height: emptyHeight)
                    stroke(rect)
                    draw(emptyText, in: rect.insetBy(dx: padding * 2, dy: padding * 2))
                    y += emptyHeight
                }

                if pageIndex == pages.count - 1, !declarationOnOwnPage {
                    draw(declarationText, in: CGRect(x: margin, y: y + 18, width: usableWidth, height: declarationHeight))
                }

                drawFooter(page: pageNumber, of: pageCount)
            }

            if declarationOnOwnPage {
                context.beginPage()
                pageNumber += 1
                draw(declarationText, in: CGRect(x: margin, y: margin, width: usableWidth, height: declarationHeight))
                drawFooter(page: pageNumber, of: pageCount)
            }
        }
    }

    private func drawRow(cells: [NSAttributedString], widths: [CGFloat], y: CGFloat, height: CGFloat, shaded: Bool) {
        var x = margin
        for (cellText, width) in zip(cells, widths) {
            let rect = CGRect(x: x, y: y, width: width, height: height)
            if shaded {
                UIColor(white: 0.9, alpha: 1).setFill()
                UIBezierPath(rect: rect).fill()
            }
            stroke(rect)
            draw(cellText, in: rect.insetBy(dx: padding, dy: padding))
            x += width
        }
    }

    private func stroke(_ rect: CGRect) {
        UIColor(white: 0.45, alpha: 1).setStroke()
        let path = UIBezierPath(rect: rect)
        path.lineWidth = 0.5
        path.stroke()
    }

    private func drawFooter(page: Int, of total: Int) {
        let made = formatter("d MMM yyyy").string(from: generatedAt)
        let note = text(
            "Made with Noise Diary on \(made). Levels are relative readings from an iPhone microphone, not calibrated decibel measurements.",
            font: UIFont.systemFont(ofSize: 7),
            color: UIColor(white: 0.35, alpha: 1)
        )
        let pageText = text("Page \(page) of \(total)", font: UIFont.systemFont(ofSize: 8), color: UIColor(white: 0.35, alpha: 1))
        let y = pageRect.height - margin - 12
        let pageWidth: CGFloat = 80
        draw(pageText, in: CGRect(x: pageRect.width - margin - pageWidth, y: y, width: pageWidth, height: 14))
        draw(note, in: CGRect(x: margin, y: y, width: pageRect.width - margin * 2 - pageWidth - 10, height: 14))
    }
}
