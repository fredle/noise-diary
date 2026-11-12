import SwiftUI
import UIKit

/// The two ways to add an entry, pinned to the bottom of the Diary and Calendar tabs.
struct NewEntryBar: View {
    @State private var showRecorder = false
    @State private var showAddLater = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                showRecorder = true
            } label: {
                Label("Record noise", systemImage: "record.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .accessibilityHint("Stamps the time now and starts recording")

            Button {
                showAddLater = true
            } label: {
                Label("Add earlier", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Write up noise that has already happened, without a recording")
        }
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
        .fullScreenCover(isPresented: $showRecorder) {
            RecordingFlowView()
        }
        .sheet(isPresented: $showAddLater) {
            AddLaterSheet()
        }
    }
}

/// One line in a list of entries.
struct EntryRow: View {
    let record: NoiseRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.noiseType.systemImage)
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(record.isAddedLater ? Color.gray : Color.red))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.typeDescription)
                    .font(.headline)
                Text("\(DiaryFormat.time(record.startedAt)) · \(DiaryFormat.duration(minutes: record.durationMinutes)) · \(record.source.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    if record.hasRecording {
                        Label(DiaryFormat.clipLength(seconds: record.recordingSeconds), systemImage: "waveform")
                    }
                    if let peak = record.peakLevel {
                        Label("Peak \(DiaryFormat.level(peak))", systemImage: "speaker.wave.3")
                    }
                    if record.isAddedLater {
                        AddedLaterBadge()
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct AddedLaterBadge: View {
    var body: some View {
        Text("Added later")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.orange.opacity(0.2)))
            .foregroundStyle(Color.orange)
            .accessibilityLabel("Added after the event, no recording")
    }
}

/// Live bars for the relative level while recording.
struct LevelMeterView: View {
    let history: [Double]
    let level: Double

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(history.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(color(for: value))
                    .frame(width: 4, height: max(4, value * 120))
            }
        }
        .frame(height: 124)
        .frame(maxWidth: .infinity)
        .animation(.linear(duration: 0.1), value: history)
        .accessibilityElement()
        .accessibilityLabel("Relative sound level")
        .accessibilityValue("\(DiaryFormat.level(level)) out of 100, \(AudioLevel.description(level))")
    }

    private func color(for value: Double) -> Color {
        switch value {
        case ..<0.5: return .green
        case ..<0.75: return .orange
        default: return .red
        }
    }
}

/// Play, pause and share one stored recording.
struct RecordingPlayerView: View {
    let record: NoiseRecord
    @StateObject private var player = AudioPlayer()

    var body: some View {
        if let name = record.audioFileName, RecordingStore.exists(name) {
            let url = RecordingStore.url(for: name)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Button {
                        player.toggle(url: url)
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(player.isPlaying ? "Pause recording" : "Play recording")

                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: player.progress)
                        Text("\(DiaryFormat.clock(seconds: player.currentTime)) of \(DiaryFormat.clipLength(seconds: record.recordingSeconds))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Share this recording")
                }
                if let average = record.averageLevel, let peak = record.peakLevel {
                    Text("Relative level: average \(DiaryFormat.level(average)), peak \(DiaryFormat.level(peak)) out of 100")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let message = player.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .onDisappear { player.stop() }
        } else if record.audioFileName != nil {
            Label("The recording file is missing.", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        } else {
            Label(record.isAddedLater ? "No recording: added after the event." : "No recording.", systemImage: "mic.slash")
                .foregroundStyle(.secondary)
        }
    }
}

/// UIKit's share sheet, for sharing several generated files at once.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
