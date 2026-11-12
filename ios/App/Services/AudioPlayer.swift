import AVFoundation
import Foundation

/// Plays back one stored clip.
@MainActor
final class AudioPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var errorMessage: String?

    private var player: AVAudioPlayer?
    private var progressTask: Task<Void, Never>?

    func toggle(url: URL) {
        if isPlaying {
            pause()
        } else {
            play(url: url)
        }
    }

    func play(url: URL) {
        do {
            if player == nil || player?.url != url {
                player = try AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
            }
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            guard let player, player.play() else {
                errorMessage = "This recording could not be played."
                return
            }
            errorMessage = nil
            isPlaying = true
            startProgress()
        } catch {
            errorMessage = "This recording could not be played."
            isPlaying = false
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        progressTask?.cancel()
        progressTask = nil
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
        progress = 0
        currentTime = 0
        progressTask?.cancel()
        progressTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startProgress() {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.update()
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func update() {
        guard let player else { return }
        if player.isPlaying {
            currentTime = player.currentTime
            progress = player.duration > 0 ? min(1, player.currentTime / player.duration) : 0
        } else if isPlaying {
            // Reached the end.
            stop()
        }
    }
}
