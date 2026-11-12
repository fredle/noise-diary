import AVFoundation
import Foundation

/// Records one short clip with metering. Recording only happens while the
/// recording screen is open; there is no background recording.
@MainActor
final class AudioRecorder: ObservableObject {
    enum State: Equatable {
        case idle
        case recording
        case finished
        case denied
        case failed(String)
    }

    /// Clips stop on their own after this long. The entry's duration is set separately.
    static let maxDuration: TimeInterval = 120
    static let historyLength = 40

    @Published private(set) var state: State = .idle
    @Published private(set) var level: Double = 0
    @Published private(set) var peak: Double = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var history: [Double] = Array(repeating: 0, count: 40)

    private(set) var fileName: String?
    private var recorder: AVAudioRecorder?
    private var meterTask: Task<Void, Never>?
    private var levelTotal: Double = 0
    private var levelSamples = 0

    var averageLevel: Double? {
        levelSamples > 0 ? levelTotal / Double(levelSamples) : nil
    }

    var peakLevel: Double? {
        levelSamples > 0 ? peak : nil
    }

    func start() async {
        guard state == .idle else { return }

        let granted: Bool
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            granted = true
        case .denied:
            granted = false
        default:
            granted = await AVAudioApplication.requestRecordPermission()
        }
        guard granted else {
            state = .denied
            return
        }
        guard state == .idle else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let file = RecordingStore.newFile()
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: file.url, settings: settings)
            recorder.isMeteringEnabled = true
            guard recorder.record() else {
                state = .failed("The microphone could not start. It may be in use by another app or a call.")
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                return
            }
            self.recorder = recorder
            fileName = file.name
            state = .recording
            startMetering()
        } catch {
            state = .failed("The microphone could not start: \(error.localizedDescription)")
        }
    }

    /// Stops and keeps the clip.
    func stop() {
        guard state == .recording, let recorder else { return }
        elapsed = max(elapsed, recorder.currentTime)
        recorder.stop()
        finish()
        state = .finished
    }

    /// Stops and deletes the clip.
    func discard() {
        recorder?.stop()
        finish()
        RecordingStore.delete(fileName)
        fileName = nil
        if state == .recording { state = .idle }
    }

    private func finish() {
        meterTask?.cancel()
        meterTask = nil
        recorder = nil
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startMetering() {
        meterTask?.cancel()
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.tick()
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func tick() {
        guard state == .recording, let recorder else { return }
        guard recorder.isRecording else {
            // Interrupted, for example by a phone call: keep what was recorded.
            stop()
            return
        }
        recorder.updateMeters()
        let current = AudioLevel.normalized(decibels: recorder.averagePower(forChannel: 0))
        let currentPeak = AudioLevel.normalized(decibels: recorder.peakPower(forChannel: 0))
        level = current
        peak = max(peak, currentPeak)
        elapsed = recorder.currentTime
        levelTotal += current
        levelSamples += 1

        var updated = history
        updated.append(current)
        if updated.count > Self.historyLength {
            updated.removeFirst(updated.count - Self.historyLength)
        }
        history = updated

        if elapsed >= Self.maxDuration {
            stop()
        }
    }
}
