import Foundation
import Speech
import AVFoundation

@MainActor
class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()
    
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Double = 0.0
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private init() {}
    
    // MARK: - Permission Management
    func requestTranscriptionPermission() async -> Bool {
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        
        switch authStatus {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    DispatchQueue.main.async {
                        continuation.resume(returning: status == .authorized)
                    }
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - Transcription
    func transcribeAudio(from audioURL: URL) async throws -> String {
        // Check permissions
        guard await requestTranscriptionPermission() else {
            throw TranscriptionError.permissionDenied
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw TranscriptionError.speechRecognizerUnavailable
        }
        
        isTranscribing = true
        transcriptionProgress = 0.0
        
        defer {
            isTranscribing = false
            transcriptionProgress = 0.0
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let recognitionRequest = SFSpeechURLRecognitionRequest(url: audioURL)
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.taskHint = .dictation
            
            self.recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let error = error {
                    DispatchQueue.main.async {
                        continuation.resume(throwing: TranscriptionError.recognitionFailed(error))
                    }
                    return
                }
                
                guard let result = result else { return }
                
                DispatchQueue.main.async {
                    // Update progress based on result finality
                    self.transcriptionProgress = result.isFinal ? 1.0 : 0.7
                    
                    if result.isFinal {
                        let transcription = result.bestTranscription.formattedString
                        continuation.resume(returning: transcription.isEmpty ? "No speech detected" : transcription)
                    }
                }
            }
        }
    }
    
    func transcribeAudioData(_ audioData: Data) async throws -> String {
        // Save data to temporary file for transcription
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        try audioData.write(to: tempURL)
        return try await transcribeAudio(from: tempURL)
    }
    
    // MARK: - Batch Transcription
    func transcribeIdeas(_ ideas: [IdeaEntity]) async {
        let untranscribedIdeas = ideas.filter { idea in
            idea.transcription == nil || idea.transcription?.contains("Recording audio...") == true
        }
        
        guard !untranscribedIdeas.isEmpty else { return }
        
        isTranscribing = true
        transcriptionProgress = 0.0
        
        defer {
            isTranscribing = false
            transcriptionProgress = 1.0
        }
        
        for (index, idea) in untranscribedIdeas.enumerated() {
            do {
                // Update progress
                let progress = Double(index) / Double(untranscribedIdeas.count)
                transcriptionProgress = progress
                
                // Transcribe using audio data if available
                let transcription: String
                if let audioData = idea.audioData {
                    transcription = try await transcribeAudioData(audioData)
                } else if let audioURLString = idea.value(forKey: "audioURL") as? String,
                         let audioURL = URL(string: audioURLString) {
                    transcription = try await transcribeAudio(from: audioURL)
                } else {
                    continue // Skip if no audio data available
                }
                
                // Update the idea with transcription
                try await StorageManager.shared.updateIdeaTranscription(idea, transcription: transcription)
                
            } catch {
                print("Transcription failed for idea \(idea.id?.uuidString ?? "unknown"): \(error)")
                // Continue with next idea
            }
        }
        
        transcriptionProgress = 1.0
    }
    
    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        isTranscribing = false
        transcriptionProgress = 0.0
    }
}

// MARK: - Error Types
enum TranscriptionError: LocalizedError {
    case permissionDenied
    case speechRecognizerUnavailable
    case recognitionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission is required to transcribe audio recordings."
        case .speechRecognizerUnavailable:
            return "Speech recognition is not available on this device."
        case .recognitionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        }
    }
} 