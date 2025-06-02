import Foundation
import SwiftUI
import Combine

@MainActor
class IdeaStashViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var ideas: [Idea] = []
    @Published var recordingState: RecordingState = .idle
    @Published var currentRecordingDuration: TimeInterval = 0
    @Published var currentTranscription: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let audioRecorder = AudioRecorder()
    private let storageManager = StorageManager.shared
    
    init() {
        setupBindings()
        loadIdeas()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Bind audio recorder state to view model
        audioRecorder.$recordingState
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingState)
        
        audioRecorder.$recordingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentRecordingDuration)
        
        audioRecorder.$transcription
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentTranscription)
        
        // Bind storage manager state to view model
        storageManager.$ideas
            .receive(on: DispatchQueue.main)
            .assign(to: &$ideas)
        
        storageManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        storageManager.$error
            .receive(on: DispatchQueue.main)
            .map { $0?.localizedDescription }
            .assign(to: &$errorMessage)
    }
    
    // MARK: - Public Methods
    func loadIdeas() {
        storageManager.loadIdeas()
    }
    
    func toggleRecording() {
        Task {
            do {
                switch recordingState {
                case .idle, .completed:
                    try await startRecording()
                case .recording:
                    try await stopRecording()
                case .processing:
                    break // Do nothing while processing
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func deleteIdea(_ idea: Idea) {
        Task {
            do {
                try await storageManager.deleteIdea(idea)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    private func startRecording() async throws {
        clearError()
        try await audioRecorder.startRecording()
    }
    
    private func stopRecording() async throws {
        clearError()
        let idea = try await audioRecorder.stopRecording()
        // Storage is handled automatically by the AudioRecorder
    }
    
    // MARK: - Computed Properties
    var statusText: String {
        switch recordingState {
        case .idle:
            return "Tap to Stash Idea"
        case .recording:
            return "Stashing Idea"
        case .processing:
            return "Processing..."
        case .completed:
            return "Saved!"
        }
    }
    
    var buttonIcon: String {
        switch recordingState {
        case .idle, .completed:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        case .processing:
            return "ellipsis"
        }
    }
    
    var buttonBackgroundColor: Color {
        switch recordingState {
        case .idle, .completed:
            return Color(red: 216/255, green: 211/255, blue: 191/255) // #D8D3BF - Original beige
        case .recording:
            return Color(red: 212/255, green: 165/255, blue: 165/255) // #D4A5A5 - Soft coral red
        case .processing:
            return Color(red: 212/255, green: 200/255, blue: 154/255) // #D4C89A - Warm amber
        }
    }
} 