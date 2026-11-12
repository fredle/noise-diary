import SwiftData
import SwiftUI

/// The fields a council diary asks for. Used for new and edited entries.
struct EntryFormView: View {
    @Binding var record: NoiseRecord
    /// Only entries added after the event can have their start time changed.
    let allowsTimeEdit: Bool

    var body: some View {
        Form {
            Section {
                if allowsTimeEdit {
                    DatePicker("Started", selection: $record.startedAt, in: ...Date())
                } else {
                    LabeledContent("Started", value: DiaryFormat.dateAndTime(record.startedAt))
                }
                Stepper {
                    LabeledContent("How long it lasted", value: DiaryFormat.duration(minutes: record.durationMinutes))
                } onIncrement: {
                    record.durationMinutes = DurationStep.increment(record.durationMinutes)
                } onDecrement: {
                    record.durationMinutes = DurationStep.decrement(record.durationMinutes)
                }
            } header: {
                Text("When")
            } footer: {
                if record.isAddedLater {
                    Text("This entry will be marked as added after the event, with the time you wrote it.")
                } else if record.hasRecording {
                    Text("The clip is short. Set how long the noise actually went on.")
                }
            }

            Section("Type of noise") {
                Picker("Type", selection: $record.noiseType) {
                    ForEach(NoiseType.allCases) { type in
                        Label(type.title, systemImage: type.systemImage).tag(type)
                    }
                }
                TextField(record.noiseType == .other ? "Describe the noise" : "Details (optional)", text: $record.noiseTypeOther)
            }

            Section {
                Picker("From", selection: $record.source) {
                    ForEach(NoiseSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                TextField("Which property (optional)", text: $record.sourceDetail)
                    .textContentType(.fullStreetAddress)
            } header: {
                Text("Where it came from")
            } footer: {
                Text("For example \u{201C}Flat 4\u{201D} or \u{201C}No. 12\u{201D}.")
            }

            Section("How it affected you") {
                ForEach(NoiseEffect.allCases) { effect in
                    Toggle(effect.title, isOn: binding(for: effect))
                }
                TextField("Anything else (optional)", text: $record.effectOther, axis: .vertical)
                    .lineLimit(1...4)
            }

            Section {
                TextField("What you heard, who else heard it, anything you did", text: $record.notes, axis: .vertical)
                    .lineLimit(3...10)
            } header: {
                Text("Notes")
            }

            if record.hasRecording {
                Section("Recording") {
                    RecordingPlayerView(record: record)
                }
            }
        }
    }

    private func binding(for effect: NoiseEffect) -> Binding<Bool> {
        Binding(
            get: { record.effects.contains(effect) },
            set: { isOn in
                if isOn {
                    record.effects.insert(effect)
                } else {
                    record.effects.remove(effect)
                }
            }
        )
    }
}

/// Writing up noise that already happened. No recording; clearly marked.
struct AddLaterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var record = NoiseRecord.addedLater(now: Date())

    var body: some View {
        NavigationStack {
            EntryFormView(record: $record, allowsTimeEdit: true)
                .navigationTitle("Add earlier noise")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                    }
                }
        }
        .lockCover()
    }

    private func save() {
        record.createdAt = Date()
        record.isAddedLater = true
        modelContext.insert(NoiseEntry(record: record))
        try? modelContext.save()
        record.rememberChoices()
        dismiss()
    }
}

/// Editing an existing entry.
struct EditEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let entry: NoiseEntry
    @State private var record: NoiseRecord

    init(entry: NoiseEntry) {
        self.entry = entry
        _record = State(initialValue: entry.record)
    }

    var body: some View {
        NavigationStack {
            EntryFormView(record: $record, allowsTimeEdit: record.isAddedLater)
                .navigationTitle("Edit entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            entry.update(from: record)
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                }
        }
        .lockCover()
    }
}
