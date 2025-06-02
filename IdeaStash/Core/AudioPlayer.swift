import Foundation
import AVFoundation
import Combine

@MainActor
class AudioPlayer: NSObject, ObservableObject {
    static let shared = AudioPlayer()
    
    @Published var isPlaying = false
    @Published var currentAudioURL: URL?
    @Published var playbackProgress: Double = 0.0
    @Published var duration: TimeInterval = 0.0
    @Published var currentTime: TimeInterval = 0.0
    
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Playback Controls
    func play(audioURL: URL) async throws {
        // Stop current playback if any
        stop()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            currentAudioURL = audioURL
            duration = audioPlayer?.duration ?? 0.0
            
            guard let player = audioPlayer else { return }
            
            if player.play() {
                isPlaying = true
                startProgressTimer()
            }
        } catch {
            throw AudioPlayerError.playbackFailed(error)
        }
    }
    
    func play(audioData: Data) async throws {
        // Stop current playback if any
        stop()
        
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            duration = audioPlayer?.duration ?? 0.0
            
            guard let player = audioPlayer else { return }
            
            if player.play() {
                isPlaying = true
                startProgressTimer()
            }
        } catch {
            throw AudioPlayerError.playbackFailed(error)
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopProgressTimer()
    }
    
    func resume() {
        guard let player = audioPlayer else { return }
        
        if player.play() {
            isPlaying = true
            startProgressTimer()
        }
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentAudioURL = nil
        playbackProgress = 0.0
        currentTime = 0.0
        duration = 0.0
        stopProgressTimer()
    }
    
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = min(time, duration)
        updateProgress()
    }
    
    // MARK: - Progress Tracking
    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgress() {
        guard let player = audioPlayer else { return }
        
        currentTime = player.currentTime
        
        if duration > 0 {
            playbackProgress = currentTime / duration
        } else {
            playbackProgress = 0.0
        }
    }
    
    // MARK: - Convenience Methods
    func togglePlayback(for audioURL: URL) async throws {
        if currentAudioURL == audioURL && isPlaying {
            pause()
        } else if currentAudioURL == audioURL && !isPlaying {
            resume()
        } else {
            try await play(audioURL: audioURL)
        }
    }
    
    func togglePlayback(for audioData: Data) async throws {
        if isPlaying {
            pause()
        } else {
            try await play(audioData: audioData)
        }
    }
    
    func isPlayingAudio(at url: URL) -> Bool {
        return currentAudioURL == url && isPlaying
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            stop()
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("Audio decode error: \(error?.localizedDescription ?? "Unknown error")")
            stop()
        }
    }
}

// MARK: - Error Types
enum AudioPlayerError: LocalizedError {
    case playbackFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .playbackFailed(let error):
            return "Audio playback failed: \(error.localizedDescription)"
        }
    }
} 