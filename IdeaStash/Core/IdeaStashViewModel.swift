import Foundation
import Combine
import Speech

@MainActor
class IdeaStashViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var ideas: [IdeaEntity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Double = 0.0
    @Published var showingTranscriptionAlert = false
    @Published var showingPermissionAlert = false
    
    // MARK: - Services
    private let storageManager = StorageManager.shared
    private let transcriptionService = TranscriptionService.shared
    private let audioPlayer = AudioPlayer.shared
    private let connectivityManager = PhoneConnectivityManager.shared
    
    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        loadIdeas()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Bind transcription service state
        transcriptionService.$isTranscribing
            .assign(to: \.isTranscribing, on: self)
            .store(in: &cancellables)
        
        transcriptionService.$transcriptionProgress
            .assign(to: \.transcriptionProgress, on: self)
            .store(in: &cancellables)
        
        // Listen for connectivity manager refresh signals
        connectivityManager.$shouldRefreshIdeas
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                Task { @MainActor in
                    print("🔄 Refreshing ideas due to connectivity update...")
                    self?.loadIdeas()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    func loadIdeas() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let loadedIdeas = try await storageManager.loadIdeas()
                ideas = loadedIdeas
            } catch {
                errorMessage = "Failed to load ideas: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    func refreshIdeas() {
        loadIdeas()
    }
    
    // MARK: - Idea Management
    func deleteIdea(_ idea: IdeaEntity) {
        Task {
            do {
                try await storageManager.deleteIdea(idea)
                // Remove from local array
                if let index = ideas.firstIndex(of: idea) {
                    ideas.remove(at: index)
                }
            } catch {
                errorMessage = "Failed to delete idea: \(error.localizedDescription)"
            }
        }
    }
    
    func deleteIdeas(at offsets: IndexSet) {
        let ideasToDelete = offsets.map { ideas[$0] }
        
        Task {
            do {
                for idea in ideasToDelete {
                    try await storageManager.deleteIdea(idea)
                }
                // Remove from local array
                ideas.remove(atOffsets: offsets)
            } catch {
                errorMessage = "Failed to delete ideas: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Audio Playback
    func togglePlayback(for idea: IdeaEntity) {
        Task {
            do {
                // Debug: Check what audio data we have for this idea
                print("🎵 Attempting to play audio for idea: \(idea.id?.uuidString ?? "unknown")")
                print("   - audioURL: \(idea.audioURL ?? "nil")")
                print("   - audioFileName: \(idea.audioFileName ?? "nil")")
                print("   - audioData size: \(idea.audioData?.count ?? 0) bytes")
                print("   - transcription: \(idea.transcription ?? "nil")")
                print("   - duration: \(idea.duration)")
                print("   - isSynced: \(idea.isSynced)")
                
                // Try audioURL first (preferred for watch-synced ideas)
                if let audioURLString = idea.audioURL,
                   let audioURL = URL(string: audioURLString) {
                    print("   - Playing from URL: \(audioURL.path)")
                    
                    // Check if file exists
                    let fileExists = FileManager.default.fileExists(atPath: audioURL.path)
                    print("   - File exists: \(fileExists)")
                    
                    if fileExists {
                        try await audioPlayer.togglePlayback(for: audioURL)
                    } else {
                        print("   - ❌ Audio file not found at path: \(audioURL.path)")
                        errorMessage = "Audio file not found. It may have been moved or deleted."
                    }
                } else if let audioData = idea.audioData {
                    print("   - Playing from audioData (\(audioData.count) bytes)")
                    try await audioPlayer.togglePlayback(for: audioData)
                } else {
                    print("   - ❌ No audio data available")
                    errorMessage = "No audio data available for this idea"
                }
            } catch {
                print("   - ❌ Audio playback failed: \(error)")
                errorMessage = "Audio playback failed: \(error.localizedDescription)"
            }
        }
    }
    
    func isPlayingAudio(for idea: IdeaEntity) -> Bool {
        if let audioURLString = idea.audioURL,
           let audioURL = URL(string: audioURLString) {
            return audioPlayer.isPlayingAudio(at: audioURL)
        }
        return false
    }
    
    // MARK: - Transcription
    func transcribeAllIdeas() {
        Task {
            do {
                // Check permission first
                let hasPermission = await transcriptionService.requestTranscriptionPermission()
                guard hasPermission else {
                    showingPermissionAlert = true
                    return
                }
                
                showingTranscriptionAlert = true
                await transcriptionService.transcribeIdeas(ideas)
                
                // Reload ideas to get updated transcriptions
                loadIdeas()
                
            } catch {
                errorMessage = "Transcription failed: \(error.localizedDescription)"
            }
        }
    }
    
    func transcribeIdea(_ idea: IdeaEntity) {
        Task {
            do {
                // Check permission first
                let hasPermission = await transcriptionService.requestTranscriptionPermission()
                guard hasPermission else {
                    showingPermissionAlert = true
                    return
                }
                
                let transcription: String
                if let audioData = idea.audioData {
                    transcription = try await transcriptionService.transcribeAudioData(audioData)
                } else if let audioURLString = idea.value(forKey: "audioURL") as? String,
                         let audioURL = URL(string: audioURLString) {
                    transcription = try await transcriptionService.transcribeAudio(from: audioURL)
                } else {
                    errorMessage = "No audio data available for transcription"
                    return
                }
                
                // Update the idea with transcription
                try await storageManager.updateIdeaTranscription(idea, transcription: transcription)
                
                // Update local array
                if let index = ideas.firstIndex(of: idea) {
                    ideas[index].transcription = transcription
                }
                
            } catch {
                errorMessage = "Transcription failed: \(error.localizedDescription)"
            }
        }
    }
    
    func cancelTranscription() {
        transcriptionService.cancelTranscription()
        showingTranscriptionAlert = false
    }
    
    // MARK: - Error Handling
    func clearError() {
        errorMessage = nil
    }
    
    func dismissTranscriptionAlert() {
        showingTranscriptionAlert = false
    }
    
    func dismissPermissionAlert() {
        showingPermissionAlert = false
    }
    
    // MARK: - Utility
    func hasUntranscribedIdeas() -> Bool {
        return ideas.contains { idea in
            idea.transcription == nil || idea.transcription?.contains("Recording audio...") == true
        }
    }
    
    func getUntranscribedCount() -> Int {
        return ideas.filter { idea in
            idea.transcription == nil || idea.transcription?.contains("Recording audio...") == true
        }.count
    }
    
    // MARK: - Debug Methods
    func debugAllIdeas() {
        print("\n🔍 DEBUG: All Ideas Data:")
        for (index, idea) in ideas.enumerated() {
            print("--- Idea \(index + 1) ---")
            print("ID: \(idea.id?.uuidString ?? "nil")")
            print("Transcription: \(idea.transcription ?? "nil")")
            print("AudioURL: \(idea.audioURL ?? "nil")")
            print("AudioData: \(idea.audioData?.count ?? 0) bytes")
            print("Duration: \(idea.duration)")
            print("IsSynced: \(idea.isSynced)")
            print("Timestamp: \(idea.timestamp?.description ?? "nil")")
            print("")
        }
    }
} 