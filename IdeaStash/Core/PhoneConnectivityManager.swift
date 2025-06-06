import Foundation
import WatchConnectivity

@MainActor
class PhoneConnectivityManager: NSObject, ObservableObject {
    static let shared = PhoneConnectivityManager()
    
    // MARK: - Published Properties
    @Published var isWatchReachable = false
    @Published var isWatchConnected = false
    @Published var syncProgress: Double = 0.0
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var shouldRefreshIdeas = false // New flag to trigger UI refresh
    
    // MARK: - Private Properties
    private let storageManager = StorageManager.shared
    private let transcriptionService = TranscriptionService.shared
    private let session = WCSession.default
    private var receivedFiles: [URL] = []
    
    override init() {
        super.init()
        setupSession()
    }
    
    // MARK: - Session Setup
    private func setupSession() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity not supported")
            return
        }
        
        session.delegate = self
        session.activate()
    }
    
    // MARK: - Public Methods
    func requestSyncFromWatch() {
        guard session.isReachable else {
            print("Watch not reachable")
            return
        }
        
        session.sendMessage(["type": "syncRequest"], replyHandler: { response in
            print("Sync request sent successfully")
        }, errorHandler: { error in
            print("Failed to send sync request: \(error)")
        })
    }
    
    func notifySyncComplete() {
        guard session.isReachable else { return }
        
        session.sendMessage(["type": "syncComplete"], replyHandler: nil, errorHandler: { error in
            print("Failed to notify sync complete: \(error)")
        })
    }
    
    func triggerIdeaRefresh() {
        shouldRefreshIdeas.toggle()
    }
    
    // MARK: - Private Methods
    private func handleReceivedIdea(from data: [String: Any]) async {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let timestamp = data["timestamp"] as? TimeInterval,
              let transcription = data["transcription"] as? String,
              let duration = data["duration"] as? Double,
              let isRecording = data["isRecording"] as? Bool else {
            print("Invalid idea data received")
            return
        }
        
        let date = Date(timeIntervalSince1970: timestamp)
        
        // Create idea without audio URL for now (will be set when file arrives)
        let idea = Idea(
            id: id,
            timestamp: date,
            audioURL: nil,
            transcription: transcription,
            duration: duration,
            isRecording: isRecording,
            isSynced: true // Mark as synced since it came from watch
        )
        
        // Store the idea
        do {
            _ = try await storageManager.saveIdea(idea)
            print("✅ Received and saved idea from watch: \(transcription)")
            triggerIdeaRefresh()
        } catch {
            print("❌ Failed to save idea from watch: \(error)")
        }
    }
    
    private func handleReceivedAudioFile(at url: URL, metadata: [String: Any]) async {
        guard let ideaIdString = metadata["ideaId"] as? String,
              let ideaId = UUID(uuidString: ideaIdString),
              let fileName = metadata["fileName"] as? String else {
            print("❌ Invalid audio file metadata")
            return
        }
        
        print("📁 Received audio file: \(fileName) for idea: \(ideaId)")
        
        // Move file to permanent location
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDirectory = documentsPath.appendingPathComponent("audio", isDirectory: true)
        
        // Create audio directory if it doesn't exist
        try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        
        let destinationURL = audioDirectory.appendingPathComponent(fileName)
        
        do {
            // Remove existing file if it exists
            try? FileManager.default.removeItem(at: destinationURL)
            
            // Move the received file to permanent location
            try FileManager.default.moveItem(at: url, to: destinationURL)
            
            // Update the idea with the audio URL
            try await storageManager.updateIdeaAudioURL(ideaId: ideaId, audioURL: destinationURL)
            
            print("💾 Audio file saved for idea: \(ideaId)")
            
            // Now transcribe the audio file
            await transcribeReceivedAudio(ideaId: ideaId, audioURL: destinationURL)
            
        } catch {
            print("❌ Failed to save audio file: \(error)")
        }
    }
    
    private func transcribeReceivedAudio(ideaId: UUID, audioURL: URL) async {
        do {
            print("🎤 Starting transcription for audio from watch...")
            
            // Check if transcription permission is available
            let hasPermission = await transcriptionService.requestTranscriptionPermission()
            guard hasPermission else {
                print("❌ Transcription permission denied")
                return
            }
            
            print("✅ Transcription permission granted, starting transcription...")
            
            // Transcribe the audio
            let transcription = try await transcriptionService.transcribeAudio(from: audioURL)
            
            print("🎯 Transcription completed: \(transcription)")
            
            // Find the idea and update its transcription
            let ideas = try await storageManager.loadIdeas()
            if let idea = ideas.first(where: { $0.id == ideaId }) {
                try await storageManager.updateIdeaTranscription(idea, transcription: transcription)
                print("✅ Successfully updated idea with transcription: \(transcription)")
                
                // Trigger UI refresh
                triggerIdeaRefresh()
            } else {
                print("❌ Could not find idea with ID: \(ideaId)")
            }
            
        } catch {
            print("❌ Failed to transcribe received audio: \(error)")
            // Even if transcription fails, keep the placeholder text so user knows there's an audio file
        }
    }
}

// MARK: - WCSessionDelegate
extension PhoneConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isWatchConnected = activationState == .activated
            if let error = error {
                print("WCSession activation failed: \(error)")
            } else {
                print("WCSession activated successfully")
            }
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            isWatchConnected = false
        }
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            isWatchConnected = false
        }
        // Reactivate session
        session.activate()
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            guard let type = message["type"] as? String else {
                replyHandler(["success": false, "error": "Invalid message type"])
                return
            }
            
            switch type {
            case "newIdea":
                if let ideaData = message["data"] as? [String: Any] {
                    await handleReceivedIdea(from: ideaData)
                    replyHandler(["success": true])
                } else {
                    replyHandler(["success": false, "error": "Invalid idea data"])
                }
            case "requestFullSync":
                // Handle full sync request if needed
                replyHandler(["success": true])
            default:
                replyHandler(["success": false, "error": "Unknown message type"])
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        Task { @MainActor in
            await handleReceivedAudioFile(at: file.fileURL, metadata: file.metadata ?? [:])
        }
    }
} 