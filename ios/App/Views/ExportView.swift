import SwiftData
import SwiftUI

struct ExportView: View {
    private struct ShareBundle: Identifiable {
        let id = UUID()
        let urls: [URL]
    }

    @Query(sort: \NoiseEntry.startedAt) private var entries: [NoiseEntry]
    @AppStorage(SettingsKeys.ownerName) private var ownerName = ""
    @AppStorage(SettingsKeys.ownerAddress) private var ownerAddress = ""
    @AppStorage(SettingsKeys.noiseAddress) private var noiseAddress = ""

    @State private var firstDay = Calendar.current.date(byAdding: .day, value: -13, to: Date()) ?? Date()
    @State private var lastDay = Date()
    @State private var includeAudio = true
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var shareBundle: ShareBundle?

    var body: some View {
        let selected = ExportBuilder.records(entries.map(\.record), from: firstDay, to: lastDay)
        let recordingCount = selected.filter { RecordingStore.exists($0.audioFileName) }.count

        NavigationStack {
            Form {
                Section {
                    DatePicker("From", selection: $firstDay, in: ...lastDay, displayedComponents: .date)
                    DatePicker("To", selection: $lastDay, in: firstDay...Date.distantFuture, displayedComponents: .date)
                    HStack {
                        Button("Last 14 days") { setLastDays(14) }
                        Spacer()
                        Button("Everything") { setEverything() }
                            .disabled(entries.isEmpty)
                    }
                    .buttonStyle(.borderless)
                } header: {
                    Text("Dates")
                } footer: {
                    Text("Most councils ask for a diary covering at least two weeks.")
                }

                Section("In this export") {
                    LabeledContent("Entries", value: "\(selected.count)")
                    LabeledContent("Recordings", value: "\(recordingCount)")
                    Toggle("Include audio files", isOn: $includeAudio)
                        .disabled(recordingCount == 0)
                }

                Section {
                    TextField("Your name", text: $ownerName)
                        .textContentType(.name)
                    TextField("Your address", text: $ownerAddress, axis: .vertical)
                        .textContentType(.fullStreetAddress)
                        .lineLimit(1...4)
                    TextField("Address the noise comes from", text: $noiseAddress, axis: .vertical)
                        .lineLimit(1...4)
                } header: {
                    Text("Printed on the diary sheet")
                } footer: {
                    Text("Optional. Anything left blank prints as a line to fill in by hand.")
                }

                Section {
                    Button {
                        export(selectedCount: selected.count)
                    } label: {
                        HStack {
                            Spacer()
                            if isWorking {
                                ProgressView()
                            } else {
                                Label("Create PDF and share", systemImage: "doc.richtext")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(selected.isEmpty || isWorking)
                } footer: {
                    if selected.isEmpty {
                        Text("There are no entries between these dates.")
                    } else {
                        Text("You get a PDF laid out like a council noise diary sheet\(includeAudio && recordingCount > 0 ? ", plus the audio clips named to match it" : ""). Nothing leaves your phone until you pick where to send it.")
                    }
                }
            }
            .navigationTitle("Export")
            .alert("Couldn't create the export", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(item: $shareBundle) { bundle in
                ActivityView(items: bundle.urls)
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea()
            }
        }
    }

    private func setLastDays(_ days: Int) {
        lastDay = Date()
        firstDay = Calendar.current.date(byAdding: .day, value: -(days - 1), to: lastDay) ?? lastDay
    }

    private func setEverything() {
        guard let first = entries.first?.startedAt, let last = entries.last?.startedAt else { return }
        firstDay = first
        lastDay = max(last, Date())
    }

    private func export(selectedCount: Int) {
        guard selectedCount > 0 else { return }
        isWorking = true
        let owner = DiaryOwnerDetails(name: ownerName, address: ownerAddress, noiseAddress: noiseAddress)
        let records = entries.map(\.record)
        do {
            let output = try ExportBuilder.build(
                records: records,
                from: firstDay,
                to: lastDay,
                owner: owner,
                includeAudio: includeAudio
            )
            shareBundle = ShareBundle(urls: output.all)
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
