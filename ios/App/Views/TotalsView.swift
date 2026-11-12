import Charts
import SwiftData
import SwiftUI

struct TotalsView: View {
    @Query(sort: \NoiseEntry.startedAt) private var entries: [NoiseEntry]
    @State private var period: SummaryPeriod = .fortnight

    var body: some View {
        let start = period.startDate(now: Date())
        let records = entries
            .filter { entry in start.map { entry.startedAt >= $0 } ?? true }
            .map(\.record)
        let summary = DiarySummary(records: records)

        NavigationStack {
            List {
                Section {
                    Picker("Period", selection: $period) {
                        ForEach(SummaryPeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if summary.entryCount == 0 {
                    Section {
                        ContentUnavailableView(
                            "Nothing in this period",
                            systemImage: "chart.bar",
                            description: Text(entries.isEmpty
                                ? "Totals appear here once you start logging noise."
                                : "Choose a longer period to see earlier entries.")
                        )
                    }
                } else {
                    Section {
                        LabeledContent("Entries", value: "\(summary.entryCount)")
                        LabeledContent("Total time", value: DiaryFormat.duration(minutes: summary.totalMinutes))
                        LabeledContent("Days with noise", value: "\(summary.daysWithNoise)")
                        LabeledContent("At night (23:00–07:00)", value: "\(summary.nightCount)")
                        LabeledContent("With a recording", value: "\(summary.recordingCount)")
                    }

                    Section {
                        Chart(summary.byDay) { day in
                            BarMark(
                                x: .value("Day", day.day, unit: .day),
                                y: .value("Entries", day.count)
                            )
                            .foregroundStyle(Color.red)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 180)
                        .padding(.vertical, 8)

                        ForEach(Array(summary.byDay.reversed())) { day in
                            LabeledContent(
                                DiaryFormat.dayHeader(day.day),
                                value: "\(DiaryFormat.entryCount(day.count)) · \(DiaryFormat.duration(minutes: day.minutes))"
                            )
                        }
                    } header: {
                        Text("By day")
                    }

                    Section("By time of day") {
                        TotalBars(totals: summary.byTimeOfDay)
                    }

                    Section("By type of noise") {
                        TotalBars(totals: summary.byType)
                    }
                }
            }
            .navigationTitle("Totals")
        }
    }
}

/// A row per category with a bar scaled to the largest count.
struct TotalBars: View {
    let totals: [DiarySummary.CategoryTotal]

    var body: some View {
        let largest = DiarySummary.maxCount(totals)
        ForEach(totals) { total in
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Label(total.title, systemImage: total.systemImage)
                    Spacer(minLength: 8)
                    Text("\(total.count)")
                        .font(.headline)
                        .monospacedDigit()
                }
                ProgressView(value: Double(total.count), total: Double(largest))
                    .tint(.red)
                Text(total.count == 0 ? "None" : "\(DiaryFormat.entryCount(total.count)), \(DiaryFormat.duration(minutes: total.minutes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(total.title)
            .accessibilityValue(total.count == 0 ? "None" : "\(DiaryFormat.entryCount(total.count)), \(DiaryFormat.duration(minutes: total.minutes))")
        }
    }
}
