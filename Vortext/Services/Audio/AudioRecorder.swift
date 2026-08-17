import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

enum AudioRecorderError: Error {
    case alreadyRecording
    case notRecording
    case unknownInputDevice(String)
}

protocol AudioRecording: Sendable {
    /// Starts capturing to a new wav file. `levelHandler` receives RMS levels
    /// in 0...1 on an arbitrary thread for waveform display.
    func start(deviceUID: String?, levelHandler: (@Sendable (Float) -> Void)?) async throws
    /// Stops and returns the finished file plus its duration.
    func stop() async throws -> (url: URL, duration: TimeInterval)
    /// Stops and deletes the partial file.
    func cancel() async
}

/// AVAudioFile is written only from the single audio tap thread, so the box
/// is safe to pass into the @Sendable tap closure.
private final class RecordingFileBox: @unchecked Sendable {
    let file: AVAudioFile
    init(file: AVAudioFile) { self.file = file }
}

actor AVAudioEngineRecorder: AudioRecording {
    private var engine: AVAudioEngine?
    private var box: RecordingFileBox?
    private var startedAt: Date?

    static func audioDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Vortext/Audio")
    }

    func start(
        deviceUID: String?, levelHandler: (@Sendable (Float) -> Void)?
    ) async throws {
        guard engine == nil else { throw AudioRecorderError.alreadyRecording }

        let engine = AVAudioEngine()
        if let deviceUID {
            try Self.setInputDevice(uid: deviceUID, on: engine)
        }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        let directory = Self.audioDirectory()
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        let url = directory.appending(path: "\(UUID().uuidString).wav")
        var settings = format.settings
        settings[AVFormatIDKey] = kAudioFormatLinearPCM
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let box = RecordingFileBox(file: file)

        input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            try? box.file.write(from: buffer)
            if let levelHandler {
                levelHandler(Self.rmsLevel(of: buffer))
            }
        }
        try engine.start()
        self.engine = engine
        self.box = box
        startedAt = .now
    }

    func stop() async throws -> (url: URL, duration: TimeInterval) {
        guard let engine, let box, let startedAt else {
            throw AudioRecorderError.notRecording
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        self.box = nil
        self.startedAt = nil
        return (box.file.url, Date.now.timeIntervalSince(startedAt))
    }

    func cancel() async {
        guard let engine, let box else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        self.box = nil
        startedAt = nil
        try? FileManager.default.removeItem(at: box.file.url)
    }

    private static func rmsLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData, buffer.frameLength > 0 else {
            return 0
        }
        let samples = data[0]
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) {
            sum += samples[i] * samples[i]
        }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        // Perceptual-ish scaling so quiet speech still animates the waveform.
        return min(1, rms * 8)
    }

    private static func setInputDevice(uid: String, on engine: AVAudioEngine) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var deviceSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var uidRef = uid as CFString
        let status = withUnsafeMutablePointer(to: &uidRef) { uidPointer in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address,
                UInt32(MemoryLayout<CFString>.size), uidPointer,
                &deviceSize, &deviceID
            )
        }
        guard status == noErr, deviceID != kAudioObjectUnknown else {
            throw AudioRecorderError.unknownInputDevice(uid)
        }
        guard let audioUnit = engine.inputNode.audioUnit else {
            throw AudioRecorderError.unknownInputDevice(uid)
        }
        let setStatus = AudioUnitSetProperty(
            audioUnit, kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global, 0, &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard setStatus == noErr else {
            throw AudioRecorderError.unknownInputDevice(uid)
        }
    }
}
