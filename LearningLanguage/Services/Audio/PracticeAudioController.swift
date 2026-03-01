import Foundation
import AVFoundation

@MainActor
final class PracticeAudioController: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var latestRecordingURL: URL?
    @Published var errorMessage: String?
    @Published var audioLevels: [CGFloat] = []
    @Published var recordingDuration: TimeInterval = 0
    @Published var playbackProgress: Double = 0 // 0...1 within current sentence

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var playbackStopTimer: Timer?
    private var playbackProgressTimer: Timer?
    private var meteringTimer: Timer?
    private var durationTimer: Timer?
    private var recordingStartDate: Date?
    private var currentStartSec: Double = 0
    private var currentEndSec: Double = 0

    private static let maxLevelSamples = 40

    func play(sourceURL: URL, startSec: Double?, endSec: Double?) {
        tearDownPlayback()

        do {
            try configureAudioSessionForPlayback()
            let audioPlayer = try AVAudioPlayer(contentsOf: sourceURL)
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()

            currentStartSec = startSec ?? 0
            currentEndSec = endSec ?? audioPlayer.duration

            audioPlayer.currentTime = max(0, currentStartSec)
            audioPlayer.play()
            player = audioPlayer
            isPlaying = true
            playbackProgress = 0

            startPlaybackProgressTimer()

            let duration = currentEndSec - currentStartSec
            if duration > 0 {
                playbackStopTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.stopPlayback()
                    }
                }
            }
        } catch {
            errorMessage = "Playback failed"
            isPlaying = false
        }
    }

    /// Seek to a position within the current sentence (0...1 progress).
    func seek(to progress: Double) {
        guard let player else { return }
        let duration = currentEndSec - currentStartSec
        guard duration > 0 else { return }

        let targetTime = currentStartSec + duration * max(0, min(1, progress))
        player.currentTime = targetTime
        playbackProgress = max(0, min(1, progress))

        if isPlaying {
            // Reset stop timer for remaining time
            playbackStopTimer?.invalidate()
            let remaining = currentEndSec - targetTime
            if remaining > 0 {
                playbackStopTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.stopPlayback()
                    }
                }
            }
        }
    }

    func stopPlayback() {
        playbackStopTimer?.invalidate()
        playbackStopTimer = nil
        playbackProgressTimer?.invalidate()
        playbackProgressTimer = nil

        player?.pause()
        isPlaying = false
    }

    /// Fully tear down the player (used when switching sentences or resetting).
    func tearDownPlayback() {
        stopPlayback()
        player = nil
        playbackProgress = 0
        currentStartSec = 0
        currentEndSec = 0
    }

    private func startPlaybackProgressTimer() {
        playbackProgressTimer?.invalidate()
        playbackProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePlaybackProgress()
            }
        }
    }

    private func updatePlaybackProgress() {
        guard let player, isPlaying else { return }
        let duration = currentEndSec - currentStartSec
        guard duration > 0 else { return }
        playbackProgress = max(0, min(1, (player.currentTime - currentStartSec) / duration))
    }

    func startRecording() async {
        do {
            let hasPermission = await requestMicrophonePermission()
            guard hasPermission else {
                errorMessage = "Microphone permission is required"
                return
            }

            try configureAudioSessionForRecording()

            let recordingURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("practice-\(UUID().uuidString).m4a")

            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 12_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder.isMeteringEnabled = true
            audioRecorder.prepareToRecord()
            audioRecorder.record()

            recorder = audioRecorder
            latestRecordingURL = recordingURL
            isRecording = true
            errorMessage = nil
            audioLevels = []
            recordingDuration = 0
            recordingStartDate = Date()

            startMeteringTimer()
            startDurationTimer()
        } catch {
            errorMessage = "Recording failed"
            isRecording = false
        }
    }

    func stopRecording() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
        recordingStartDate = nil

        recorder?.stop()
        recorder = nil
        isRecording = false
    }

    private func startMeteringTimer() {
        meteringTimer?.invalidate()
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetering()
            }
        }
    }

    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateDuration()
            }
        }
    }

    private func updateMetering() {
        guard let recorder, recorder.isRecording else {
            return
        }

        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        // Normalize from dB range (-60...0) to 0...1
        let normalizedPower = max(0, min(1, (power + 60) / 60))
        let level = CGFloat(normalizedPower)

        audioLevels.append(level)
        if audioLevels.count > Self.maxLevelSamples {
            audioLevels.removeFirst(audioLevels.count - Self.maxLevelSamples)
        }
    }

    private func updateDuration() {
        guard let startDate = recordingStartDate else {
            return
        }

        recordingDuration = Date().timeIntervalSince(startDate)
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            #if os(iOS)
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            #else
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
            #endif
        }
    }

    private func configureAudioSessionForPlayback() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try session.setActive(true)
        #endif
    }

    private func configureAudioSessionForRecording() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)
        #endif
    }
}

extension PracticeAudioController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.isPlaying = false
            self?.playbackStopTimer?.invalidate()
            self?.playbackStopTimer = nil
        }
    }
}
