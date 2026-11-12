import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var lock: AppLock
    @AppStorage(SettingsKeys.lockEnabled) private var lockEnabled = false
    @Query private var entries: [NoiseEntry]
    @State private var lockMessage: String?
    @State private var confirmDeleteAll = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Lock with \(AppLock.methodName)", isOn: Binding(
                        get: { lockEnabled },
                        set: { newValue in changeLock(to: newValue) }
                    ))
                    .disabled(!AppLock.isAvailable && !lockEnabled)
                } header: {
                    Text("Privacy")
                } footer: {
                    if let lockMessage {
                        Text(lockMessage)
                    } else if !AppLock.isAvailable {
                        Text("Set a passcode for this iPhone in the Settings app to use the lock.")
                    } else {
                        Text("Your diary is hidden whenever you leave the app and needs \(AppLock.methodName) or your passcode to open.")
                    }
                }

                Section("About the sound level") {
                    Text("While recording, Noise Diary shows a relative level from 0 to 100 based on the iPhone microphone. It helps you compare one noise with another, but it is not a calibrated decibel measurement and should not be presented as one. The recording itself is the stronger evidence.")
                        .font(.callout)
                }

                Section("Your data") {
                    Text("Entries and recordings are stored only on this iPhone. Nothing is uploaded or shared unless you export it yourself. Deleting the app deletes the diary, so export it before you do.")
                        .font(.callout)
                    LabeledContent("Entries", value: "\(entries.count)")
                    Button("Delete all entries", role: .destructive) {
                        confirmDeleteAll = true
                    }
                    .disabled(entries.isEmpty)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete all entries?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button("Delete \(DiaryFormat.entryCount(entries.count)) and recordings", role: .destructive) {
                    deleteAll()
                }
            } message: {
                Text("This cannot be undone. Export your diary first if you might need it.")
            }
        }
    }

    private func changeLock(to enabled: Bool) {
        Task {
            let changed = await lock.setEnabled(enabled)
            if changed {
                lockEnabled = enabled
                lockMessage = nil
            } else {
                lockMessage = "The lock was not turned on because \(AppLock.methodName) didn't succeed."
            }
        }
    }

    private func deleteAll() {
        for entry in entries {
            RecordingStore.delete(entry.audioFileName)
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }
}
