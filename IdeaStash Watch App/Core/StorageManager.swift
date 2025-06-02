import Foundation
import CoreData

class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    // MARK: - Published Properties
    @Published var ideas: [Idea] = []
    @Published var isLoading = false
    @Published var error: StorageError?
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "IdeaStashModel")
        
        // Configure for CloudKit if needed in the future
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    private var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    private init() {
        loadIdeas()
    }
    
    // MARK: - Public Methods
    func saveIdea(_ idea: Idea) async throws {
        await MainActor.run {
            isLoading = true
        }
        
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let ideaEntity = IdeaEntity(context: self.context)
                    ideaEntity.id = idea.id
                    ideaEntity.timestamp = idea.timestamp
                    ideaEntity.transcription = idea.transcription
                    ideaEntity.duration = idea.duration
                    ideaEntity.isRecording = idea.isRecording
                    ideaEntity.isSynced = false // Mark as not synced for future cloud upload
                    
                    // Handle audio file
                    if let audioURL = idea.audioURL {
                        ideaEntity.audioFileName = audioURL.lastPathComponent
                        ideaEntity.audioData = try? Data(contentsOf: audioURL)
                    }
                    
                    try self.context.save()
                    
                    DispatchQueue.main.async {
                        self.loadIdeas()
                        self.isLoading = false
                        continuation.resume()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.error = .saveFailed(error)
                        self.isLoading = false
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    func loadIdeas() {
        context.perform {
            do {
                let request: NSFetchRequest<IdeaEntity> = IdeaEntity.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
                
                let entities = try self.context.fetch(request)
                let ideas = entities.compactMap { entity in
                    self.ideaFromEntity(entity)
                }
                
                DispatchQueue.main.async {
                    self.ideas = ideas
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = .loadFailed(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    func deleteIdea(_ idea: Idea) async throws {
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request: NSFetchRequest<IdeaEntity> = IdeaEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", idea.id as CVarArg)
                    
                    let entities = try self.context.fetch(request)
                    for entity in entities {
                        // Delete associated audio file if it exists
                        if let audioData = entity.audioData,
                           let audioFileName = entity.audioFileName {
                            self.deleteAudioFile(fileName: audioFileName)
                        }
                        
                        self.context.delete(entity)
                    }
                    
                    try self.context.save()
                    
                    DispatchQueue.main.async {
                        self.loadIdeas()
                        continuation.resume()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.error = .deleteFailed(error)
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    func getUnsyncedIdeas() async -> [Idea] {
        await withCheckedContinuation { continuation in
            context.perform {
                do {
                    let request: NSFetchRequest<IdeaEntity> = IdeaEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "isSynced == NO")
                    
                    let entities = try self.context.fetch(request)
                    let ideas = entities.compactMap { entity in
                        self.ideaFromEntity(entity)
                    }
                    
                    continuation.resume(returning: ideas)
                } catch {
                    print("Failed to fetch unsynced ideas: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func markAsSynced(_ idea: Idea) async throws {
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request: NSFetchRequest<IdeaEntity> = IdeaEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", idea.id as CVarArg)
                    
                    let entities = try self.context.fetch(request)
                    for entity in entities {
                        entity.isSynced = true
                    }
                    
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func ideaFromEntity(_ entity: IdeaEntity) -> Idea? {
        guard let id = entity.id,
              let timestamp = entity.timestamp else {
            return nil
        }
        
        var audioURL: URL?
        if let audioFileName = entity.audioFileName,
           let audioData = entity.audioData {
            audioURL = saveAudioDataToFile(audioData, fileName: audioFileName)
        }
        
        return Idea(
            id: id,
            timestamp: timestamp,
            audioURL: audioURL,
            transcription: entity.transcription,
            duration: entity.duration,
            isRecording: entity.isRecording
        )
    }
    
    private func saveAudioDataToFile(_ data: Data, fileName: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try data.write(to: audioURL)
            return audioURL
        } catch {
            print("Failed to write audio file: \(error)")
            return nil
        }
    }
    
    private func deleteAudioFile(fileName: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        try? FileManager.default.removeItem(at: audioURL)
    }
    
    // MARK: - Core Data Helpers
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save context failed: \(error)")
            }
        }
    }
}

// MARK: - Storage Errors
enum StorageError: Error, LocalizedError {
    case saveFailed(Error)
    case loadFailed(Error)
    case deleteFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save idea: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load ideas: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete idea: \(error.localizedDescription)"
        }
    }
} 