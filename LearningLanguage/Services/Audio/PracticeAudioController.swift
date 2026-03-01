import Foundation
import AVFoundation

@MainActor
final class PracticeAudioController: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var latestRecordingURL: URL?
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var playbackStopTimer: Timer?

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
            audioRecorder.prepareToRecord()
            audioRecorder.record()

            recorder = audioRecorder
            latestRecordingURL = recordingURL
            isRecording = true
            errorMessage = nil
        } catch {
            errorMessage = "Recording failed"
            isRecording = false
        }
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        isRecording = false
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
