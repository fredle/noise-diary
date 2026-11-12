import SwiftData
import SwiftUI

struct CalendarScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NoiseEntry.startedAt) private var entries: [NoiseEntry]
    @State private var month = MonthLayout(containing: Date())
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())

    var body: some View {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.startedAt) }
        let dayEntries = byDay[selectedDay] ?? []
        let records = dayEntries.map(\.record)

        NavigationStack {
            List {
                Section {
                    MonthGridView(
                        month: month,
                        counts: byDay.mapValues(\.count),
                        selectedDay: $selectedDay,
                        onChangeMonth: { offset in
                            month = month.shifted(by: offset)
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))
                }

                Section {
                    if dayEntries.isEmpty {
                        Text("No noise logged on this day.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(dayEntries) { entry in
                            NavigationLink(value: entry) {
                                EntryRow(record: entry.record)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                let entry = dayEntries[index]
                                RecordingStore.delete(entry.audioFileName)
                                modelContext.delete(entry)
                            }
                            try? modelContext.save()
                        }
                    }
                } header: {
                    DayHeader(day: selectedDay, records: records)
                }
            }
            .navigationTitle("Calendar")
            .navigationDestination(for: NoiseEntry.self) { entry in
                EntryDetailView(entry: entry)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Today") {
                        let today = calendar.startOfDay(for: Date())
                        selectedDay = today
                        month = MonthLayout(containing: today)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                NewEntryBar()
            }
        }
    }
}

struct MonthGridView: View {
    let month: MonthLayout
    let counts: [Date: Int]
    @Binding var selectedDay: Date
    let onChangeMonth: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    onChangeMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .padding(8)
                }
                .accessibilityLabel("Previous month")

                Spacer()
                Text(month.monthStart.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                Spacer()

                Button {
                    onChangeMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .padding(8)
                }
                .accessibilityLabel("Next month")
            }
            .buttonStyle(.borderless)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(month.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                ForEach(Array(month.cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear
                            .frame(height: 1)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let calendar = Calendar.current
        let count = counts[day] ?? 0
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)

        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.callout.weight(isToday ? .bold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                Text(count > 0 ? "\(count)" : " ")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(isSelected ? Color.white : Color.red)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.red : (count > 0 ? Color.red.opacity(min(0.35, 0.1 + 0.06 * Double(count))) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isToday && !isSelected ? Color.red : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide).day().month(.wide))), \(count == 0 ? "no entries" : DiaryFormat.entryCount(count))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
