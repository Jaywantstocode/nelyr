@preconcurrency import WhisperKit
import Foundation

@MainActor
final class WhisperAudioRecorder: VoiceRecording {
    private let processor = AudioProcessor()
    private let settings: DailyDeskSettings
    private var recording = false

    init(settings: DailyDeskSettings = .shared) {
        self.settings = settings
    }

    static var inputDevices: [(id: UInt32, name: String)] {
        AudioProcessor.getAudioDevices().map { (UInt32($0.id), $0.name) }
    }

    static func testInput(deviceID: UInt32) async -> Bool {
        guard await AudioProcessor.requestRecordPermission() else { return false }
        let testProcessor = AudioProcessor()
        do {
            try testProcessor.startRecordingLive(inputDeviceID: deviceID == 0 ? nil : deviceID)
            try? await Task.sleep(for: .seconds(1.2))
            testProcessor.stopRecording()
            return testProcessor.audioSamples.contains { abs($0) > 0.002 }
        } catch {
            testProcessor.stopRecording()
            return false
        }
    }

    func requestPermission() async -> Bool {
        await AudioProcessor.requestRecordPermission()
    }

    func start() throws {
        guard !recording else { throw VoiceDictationError.alreadyRecording }
        do {
            let deviceID = settings.microphoneDeviceID
            try processor.startRecordingLive(inputDeviceID: deviceID == 0 ? nil : deviceID)
            recording = true
        } catch {
            throw VoiceDictationError.recordingUnavailable(error.localizedDescription)
        }
    }

    func stop() -> [Float] {
        guard recording else { return [] }
        processor.stopRecording()
        recording = false
        let samples = Array(processor.audioSamples)
        processor.audioSamples.removeAll(keepingCapacity: false)
        return samples
    }

    func cancel() {
        processor.stopRecording()
        processor.audioSamples.removeAll(keepingCapacity: false)
        recording = false
    }
}
