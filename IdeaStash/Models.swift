import Foundation

// MARK: - Core Models
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

// MARK: - Recording States
enum RecordingState {
    case idle
    case recording
    case processing
    case completed
}

// MARK: - Dummy Data Provider
class DummyDataProvider: ObservableObject {
    @Published var ideas: [Idea] = []
    @Published var recordingState: RecordingState = .idle
    @Published var currentRecordingDuration: TimeInterval = 0
    
    init() {
        loadDummyData()
    }
    
    private func loadDummyData() {
        let calendar = Calendar.current
        let now = Date()
        
        ideas = [
            Idea(
                timestamp: calendar.date(byAdding: .minute, value: -15, to: now) ?? now,
                transcription: "Remember to call mom about dinner plans this weekend",
                duration: 3.2
            ),
            Idea(
                timestamp: calendar.date(byAdding: .hour, value: -2, to: now) ?? now,
                transcription: "App idea: A voice recorder for capturing thoughts quickly",
                duration: 5.8
            ),
            Idea(
                timestamp: calendar.date(byAdding: .hour, value: -4, to: now) ?? now,
                transcription: "Buy groceries: milk, eggs, bread, and coffee",
                duration: 2.1
            ),
            Idea(
                timestamp: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                transcription: "Meeting notes: discuss quarterly goals and team restructuring",
                duration: 12.5
            ),
            Idea(
                timestamp: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                transcription: "Gift idea for Sarah's birthday: that book she mentioned",
                duration: 1.8
            )
        ].sorted { $0.timestamp > $1.timestamp }
    }
    
    // MARK: - Recording Actions
    func startRecording() {
        recordingState = .recording
        currentRecordingDuration = 0
        
        // Simulate recording duration updates
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if self.recordingState == .recording {
                self.currentRecordingDuration += 0.1
            } else {
                timer.invalidate()
            }
        }
    }
    
    func stopRecording() {
        recordingState = .processing
        
        // Simulate processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let newIdea = Idea(
                transcription: "New voice recording \(Int.random(in: 1...100))",
                duration: self.currentRecordingDuration
            )
            
            self.ideas.insert(newIdea, at: 0)
            self.recordingState = .completed
            self.currentRecordingDuration = 0
            
            // Reset to idle after showing completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.recordingState = .idle
            }
        }
    }
    
    func toggleRecording() {
        switch recordingState {
        case .idle, .completed:
            startRecording()
        case .recording:
            stopRecording()
        case .processing:
            break // Do nothing while processing
        }
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