import Foundation
import CoreData

// MARK: - Recording States
enum RecordingState {
    case idle
    case recording
    case processing
    case completed
}

// MARK: - Legacy Idea struct (for compatibility)
struct Idea: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let audioURL: URL?
    let transcription: String?
    let duration: TimeInterval
    let isRecording: Bool
    
    init(timestamp: Date = Date(), audioURL: URL? = nil, transcription: String? = nil, duration: TimeInterval = 0, isRecording: Bool = false) {
        self.timestamp = timestamp
        self.audioURL = audioURL
        self.transcription = transcription
        self.duration = duration
        self.isRecording = isRecording
    }
}

// MARK: - Formatting Helpers
extension TimeInterval {
    var formattedDuration: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension Date {
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
} 