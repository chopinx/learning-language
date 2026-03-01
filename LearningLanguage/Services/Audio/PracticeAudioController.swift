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

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var playbackStopTimer: Timer?
    private var meteringTimer: Timer?
    private var durationTimer: Timer?
    private var recordingStartDate: Date?

    private static let maxLevelSamples = 40

    func play(sourceURL: URL, startSec: Double?, endSec: Double?) {
        stopPlayback()

        do {
            try configureAudioSessionForPlayback()
            let audioPlayer = try AVAudioPlayer(contentsOf: sourceURL)
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()

            if let startSec {
                audioPlayer.currentTime = max(0, startSec)
            }

            audioPlayer.play()
            player = audioPlayer
            isPlaying = true

            if let startSec, let endSec, endSec > startSec {
                let duration = endSec - startSec
                playbackStopTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                    self?.stopPlayback()
                }
            }
        } catch {
            errorMessage = "Playback failed"
            isPlaying = false
        }
    }

    func stopPlayback() {
        playbackStopTimer?.invalidate()
        playbackStopTimer = nil

        player?.stop()
        player = nil
        isPlaying = false
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
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func configureAudioSessionForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try session.setActive(true)
    }

    private func configureAudioSessionForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
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
