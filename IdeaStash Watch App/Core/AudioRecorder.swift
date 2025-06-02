import Foundation
import AVFoundation
import WatchKit

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var transcription = ""
    @Published var recordingState: RecordingState = .idle
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var currentRecordingURL: URL?
    
    // MARK: - Dependencies
    private let storageManager = StorageManager.shared
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Setup
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Permission Management
    func requestPermissions() async -> Bool {
        return await requestMicrophonePermission()
    }
    
    private func requestMicrophonePermission() async -> Bool {
        // Use AVAudioSession for watchOS compatibility
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - Recording Control
    func startRecording() async throws {
        guard !isRecording else { return }
        
        let hasPermissions = await requestPermissions()
        guard hasPermissions else {
            throw RecordingError.permissionDenied
        }
        
        // Reset state
        transcription = "Recording audio... (Transcription will be available when synced to iPhone)"
        recordingDuration = 0
        recordingState = .recording
        isRecording = true
        
        // Setup audio file recording
        currentRecordingURL = try createAudioFileURL()
        try setupAudioRecorder()
        
        // Start audio recording
        audioRecorder?.record()
        
        // Start timer for duration tracking
        startRecordingTimer()
        
        // Haptic feedback
        WKInterfaceDevice.current().play(.start)
    }
    
    func stopRecording() async throws -> Idea {
        guard isRecording else { throw RecordingError.notRecording }
        
        // Stop recording
        isRecording = false
        recordingState = .processing
        audioRecorder?.stop()
        stopRecordingTimer()
        
        // Create placeholder transcription message
        let placeholderTranscription = "Audio recorded successfully. Transcription will be processed when the app syncs with your iPhone."
        
        // Create and save idea
        let idea = Idea(
            timestamp: Date(),
            audioURL: currentRecordingURL,
            transcription: placeholderTranscription,
            duration: recordingDuration,
            isRecording: false
        )
        
        // Save to local storage
        try await storageManager.saveIdea(idea)
        
        recordingState = .completed
        
        // Reset state after delay
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                self.recordingState = .idle
                self.currentRecordingURL = nil
                self.transcription = ""
            }
        }
        
        // Haptic feedback
        WKInterfaceDevice.current().play(.success)
        
        return idea
    }
    
    // MARK: - Private Recording Methods
    private func createAudioFileURL() throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent("recording_\(UUID().uuidString).m4a")
        return audioURL
    }
    
    private func setupAudioRecorder() throws {
        guard let url = currentRecordingURL else {
            throw RecordingError.fileCreationFailed
        }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.prepareToRecord()
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isRecording else { return }
                self.recordingDuration += 0.1
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

// MARK: - Delegates
extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                print("Audio recording failed")
            }
        }
    }
}

// MARK: - Errors
enum RecordingError: Error, LocalizedError {
    case permissionDenied
    case notRecording
    case fileCreationFailed
    case speechRecognitionFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied"
        case .notRecording:
            return "No active recording to stop"
        case .fileCreationFailed:
            return "Failed to create audio file"
        case .speechRecognitionFailed:
            return "Speech recognition setup failed"
        }
    }
} 