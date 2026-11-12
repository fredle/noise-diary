import SwiftData
import SwiftUI

struct DiaryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NoiseEntry.startedAt, order: .reverse) private var entries: [NoiseEntry]

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView {
                        Label("No noise logged yet", systemImage: "waveform")
                    } description: {
                        Text("When the noise starts, tap Record noise. Councils usually ask for at least two weeks of entries before they investigate.")
                    }
                } else {
                    List {
                        ForEach(DayGrouping.groups(entries, date: { $0.startedAt })) { group in
                            Section {
                                ForEach(group.items) { entry in
                                    NavigationLink(value: entry) {
                                        EntryRow(record: entry.record)
                                    }
                                }
                                .onDelete { offsets in
                                    delete(offsets.map { group.items[$0] })
                                }
                            } header: {
                                DayHeader(day: group.day, records: group.items.map(\.record))
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Noise Diary")
            .navigationDestination(for: NoiseEntry.self) { entry in
                EntryDetailView(entry: entry)
            }
            .safeAreaInset(edge: .bottom) {
                NewEntryBar()
            }
        }
    }

    private func delete(_ items: [NoiseEntry]) {
        for entry in items {
            RecordingStore.delete(entry.audioFileName)
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }
}

/// "Tuesday 10 November · 3 entries · 2 h 15 min"
struct DayHeader: View {
    let day: Date
    let records: [NoiseRecord]

    var body: some View {
        let minutes = records.reduce(0) { $0 + $1.durationMinutes }
        VStack(alignment: .leading, spacing: 2) {
            Text(DiaryFormat.dayHeader(day))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("\(DiaryFormat.entryCount(records.count)) · \(DiaryFormat.duration(minutes: minutes))")
                .font(.caption)
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }
}

struct EntryDetailView: View {
    let entry: NoiseEntry
    @State private var isEditing = false

    var body: some View {
        let record = entry.record
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: record.noiseType.systemImage)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(record.isAddedLater ? Color.gray : Color.red))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.typeDescription)
                            .font(.title3.bold())
                        Text(DiaryFormat.dayHeader(record.startedAt))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                if record.isAddedLater {
                    VStack(alignment: .leading, spacing: 4) {
                        AddedLaterBadge()
                        Text("Written on \(DiaryFormat.dateAndTime(record.createdAt)), after the noise happened.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("When") {
                LabeledContent("Started", value: DiaryFormat.time(record.startedAt))
                LabeledContent("Finished", value: DiaryFormat.time(record.endedAt))
                LabeledContent("Lasted", value: DiaryFormat.duration(minutes: record.durationMinutes))
                LabeledContent("Time of day", value: TimeOfDay(date: record.startedAt).title)
            }

            Section("Where it came from") {
                Text(record.sourceDescription)
            }

            Section("How it affected you") {
                if record.effectTitles.isEmpty {
                    Text("Not noted")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(record.effectTitles, id: \.self) { title in
                        Text(title)
                    }
                }
            }

            if !record.trimmedNotes.isEmpty {
                Section("Notes") {
                    Text(record.trimmedNotes)
                        .textSelection(.enabled)
                }
            }

            Section("Recording") {
                RecordingPlayerView(record: record)
            }
        }
        .navigationTitle(DiaryFormat.time(record.startedAt))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditEntrySheet(entry: entry)
        }
    }
}
