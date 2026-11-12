import SwiftData
import SwiftUI
import UIKit

/// One-tap entry: the start time is stamped when this screen opens and the
/// clip starts straight away. Stopping moves on to the diary fields.
struct RecordingFlowView: View {
    private enum Stage {
        case recording
        case details
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @StateObject private var recorder = AudioRecorder()
    @State private var stage: Stage = .recording
    @State private var record: NoiseRecord
    @State private var confirmDiscard = false

    init() {
        _record = State(initialValue: NoiseRecord.live(startedAt: Date()))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .recording:
                    recordingContent
                case .details:
                    EntryFormView(record: $record, allowsTimeEdit: false)
                }
            }
            .navigationTitle(stage == .recording ? "Recording" : "Describe the noise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .lockCover()
        .interactiveDismissDisabled()
        .task {
            await recorder.start()
        }
        .onChange(of: recorder.state) { _, newState in
            if newState == .finished {
                moveToDetails()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // No background recording: leaving the app ends the clip.
            if phase == .background {
                recorder.stop()
            }
        }
        .confirmationDialog("Discard this entry?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard entry and recording", role: .destructive) {
                recorder.discard()
                RecordingStore.delete(record.audioFileName)
                dismiss()
            }
        } message: {
            Text("The recording will be deleted. This cannot be undone.")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if stage == .recording {
                Button("Cancel") {
                    recorder.discard()
                    dismiss()
                }
            } else {
                Button("Discard") { confirmDiscard = true }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            if stage == .details {
                Button("Save") { save() }
            }
        }
    }

    @ViewBuilder
    private var recordingContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Started at")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(DiaryFormat.time(record.startedAt))
                        .font(.largeTitle.bold())
                        .monospacedDigit()
                    Text(DiaryFormat.dayHeader(record.startedAt))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)

                switch recorder.state {
                case .idle:
                    ProgressView("Starting the microphone…")
                        .padding(.top, 40)
                case .recording, .finished:
                    activeRecording
                case .denied:
                    microphoneUnavailable(
                        title: "Microphone access is off",
                        message: "Turn on the microphone for Noise Diary in Settings to record clips. You can still log this noise now without a recording."
                    )
                case .failed(let message):
                    microphoneUnavailable(title: "Couldn't start recording", message: message)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    private var activeRecording: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
                Text("\(DiaryFormat.clock(seconds: recorder.elapsed)) of \(DiaryFormat.clock(seconds: AudioRecorder.maxDuration))")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Recording, \(DiaryFormat.clipLength(seconds: recorder.elapsed))")

            LevelMeterView(history: recorder.history, level: recorder.level)

            VStack(spacing: 4) {
                Text("Level \(DiaryFormat.level(recorder.level)) · Peak \(DiaryFormat.level(recorder.peak))")
                    .font(.headline)
                    .monospacedDigit()
                Text("A relative level from the phone's microphone, not a decibel reading.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                recorder.stop()
            } label: {
                Label("Stop and describe", systemImage: "stop.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)

            Text("Recording stops by itself after \(DiaryFormat.clipLength(seconds: AudioRecorder.maxDuration)). Keep the phone still and pointed towards the noise.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func microphoneUnavailable(title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                moveToDetails()
            } label: {
                Text("Log without a recording")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            if recorder.state == .denied, let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") { openURL(url) }
            }
        }
        .padding(.top, 20)
    }

    private func moveToDetails() {
        guard stage == .recording else { return }
        if recorder.state == .finished, let name = recorder.fileName {
            record.audioFileName = name
            record.recordingSeconds = recorder.elapsed
            record.averageLevel = recorder.averageLevel
            record.peakLevel = recorder.peakLevel
            record.durationMinutes = max(1, Int((recorder.elapsed / 60).rounded(.up)))
        }
        stage = .details
    }

    private func save() {
        modelContext.insert(NoiseEntry(record: record))
        try? modelContext.save()
        record.rememberChoices()
        dismiss()
    }
}
