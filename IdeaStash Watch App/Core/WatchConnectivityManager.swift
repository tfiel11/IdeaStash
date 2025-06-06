import Foundation
import WatchConnectivity

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    // MARK: - Published Properties
    @Published var isReachable = false
    @Published var isConnected = false
    @Published var syncProgress: Double = 0.0
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    
    // MARK: - Private Properties
    private let storageManager = StorageManager.shared
    private let session = WCSession.default
    private var pendingFileTransfers: [WCSessionFileTransfer] = []
    
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
    func syncAllUnsyncedIdeas() async {
        guard session.isReachable else {
            print("Phone not reachable")
            return
        }
        
        await MainActor.run {
            isSyncing = true
            syncProgress = 0.0
        }
        
        let unsyncedIdeas = await storageManager.getUnsyncedIdeas()
        
        guard !unsyncedIdeas.isEmpty else {
            await MainActor.run {
                isSyncing = false
                syncProgress = 1.0
                lastSyncDate = Date()
            }
            return
        }
        
        for (index, idea) in unsyncedIdeas.enumerated() {
            await syncIdea(idea)
            
            await MainActor.run {
                syncProgress = Double(index + 1) / Double(unsyncedIdeas.count)
            }
        }
        
        await MainActor.run {
            isSyncing = false
            syncProgress = 1.0
            lastSyncDate = Date()
        }
    }
    
    func syncIdea(_ idea: Idea) async {
        // Prepare idea metadata for immediate transfer
        let ideaData: [String: Any] = [
            "id": idea.id.uuidString,
            "timestamp": idea.timestamp.timeIntervalSince1970,
            "transcription": idea.transcription ?? "",
            "duration": idea.duration,
            "isRecording": idea.isRecording,
            "audioFileName": idea.audioURL?.lastPathComponent ?? ""
        ]
        
        // Send metadata immediately
        session.sendMessage(["type": "newIdea", "data": ideaData], replyHandler: { response in
            Task { @MainActor in
                if let success = response["success"] as? Bool, success {
                    // Mark as synced if metadata transfer successful
                    try? await self.storageManager.markAsSynced(idea)
                }
            }
        }, errorHandler: { error in
            print("Failed to send idea metadata: \(error)")
        })
        
        // Transfer audio file if it exists
        if let audioURL = idea.audioURL,
           FileManager.default.fileExists(atPath: audioURL.path) {
            
            let transfer = session.transferFile(audioURL, metadata: [
                "ideaId": idea.id.uuidString,
                "fileName": audioURL.lastPathComponent
            ])
            
            pendingFileTransfers.append(transfer)
        }
    }
    
    func requestFullSync() {
        guard session.isReachable else { return }
        
        session.sendMessage(["type": "requestFullSync"], replyHandler: nil, errorHandler: { error in
            print("Failed to request full sync: \(error)")
        })
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isConnected = activationState == .activated
            if let error = error {
                print("WCSession activation failed: \(error)")
            } else {
                print("WCSession activated successfully")
                // Auto-sync when connection is established
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    await syncAllUnsyncedIdeas()
                }
            }
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
            if session.isReachable {
                // Phone became reachable, sync unsynced ideas
                Task {
                    await syncAllUnsyncedIdeas()
                }
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            guard let type = message["type"] as? String else { return }
            
            switch type {
            case "syncRequest":
                await syncAllUnsyncedIdeas()
            case "syncComplete":
                lastSyncDate = Date()
                isSyncing = false
            default:
                break
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("File transfer failed: \(error)")
            } else {
                print("File transfer completed successfully")
                if let index = pendingFileTransfers.firstIndex(of: fileTransfer) {
                    pendingFileTransfers.remove(at: index)
                }
            }
        }
    }
} 