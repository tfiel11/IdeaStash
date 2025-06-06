import Foundation
import CoreData
import CloudKit

@MainActor
class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "IdeaStashModel")
        
        // Configure for CloudKit
        let storeDescription = container.persistentStoreDescriptions.first!
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Handle CloudKit initialization gracefully
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                print("Core Data error: \(error)")
                
                // Check if it's a CloudKit account issue
                if error.domain == NSCocoaErrorDomain && error.code == 134400 {
                    print("⚠️ CloudKit is not available: No iCloud account signed in. The app will work locally only.")
                    print("💡 To test CloudKit: Sign in to iCloud in iOS Settings > Apple ID")
                } else {
                    print("❌ Critical Core Data error - app may not function properly")
                    fatalError("Failed to load Core Data stack: \(error)")
                }
            } else {
                print("✅ Core Data stack loaded successfully for: \(storeDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    private var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    private init() {
        // Force lazy initialization of persistent container
        _ = persistentContainer
    }
    
    // MARK: - CRUD Operations
    func saveIdea(
        audioData: Data,
        audioFileName: String,
        duration: TimeInterval,
        transcription: String? = nil
    ) async throws -> IdeaEntity {
        let idea = IdeaEntity(context: context)
        idea.id = UUID()
        idea.timestamp = Date()
        idea.audioData = audioData
        idea.audioFileName = audioFileName
        idea.duration = duration
        idea.transcription = transcription
        idea.isRecording = false
        idea.isSynced = false
        
        // Save audio file to documents directory
        let audioURL = try saveAudioFile(data: audioData, fileName: audioFileName)
        idea.audioURL = audioURL.absoluteString
        
        try await saveContext()
        return idea
    }
    
    func loadIdeas() async throws -> [IdeaEntity] {
        let request: NSFetchRequest<IdeaEntity> = IdeaEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \IdeaEntity.timestamp, ascending: false)]
        
        return try context.fetch(request)
    }
    
    func deleteIdea(_ idea: IdeaEntity) async throws {
        // Delete audio file if it exists
        if let audioURLString = idea.audioURL,
           let audioURL = URL(string: audioURLString) {
            try? FileManager.default.removeItem(at: audioURL)
        }
        
        context.delete(idea)
        try await saveContext()
    }
    
    func updateIdeaTranscription(_ idea: IdeaEntity, transcription: String) async throws {
        idea.transcription = transcription
        try await saveContext()
    }
    
    func getUnsyncedIdeas() async throws -> [IdeaEntity] {
        let request: NSFetchRequest<IdeaEntity> = IdeaEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isSynced == false")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \IdeaEntity.timestamp, ascending: false)]
        
        return try context.fetch(request)
    }
    
    func markAsSynced(_ idea: IdeaEntity) async throws {
        idea.isSynced = true
        try await saveContext()
    }
    
    func updateIdeaAudioURL(ideaId: UUID, audioURL: URL) async throws {
        let request: NSFetchRequest<IdeaEntity> = IdeaEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", ideaId as CVarArg)
        
        let ideas = try context.fetch(request)
        guard let idea = ideas.first else {
            throw NSError(domain: "StorageManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Idea not found"])
        }
        
        idea.audioURL = audioURL.absoluteString
        try await saveContext()
    }
    
    func saveIdea(_ idea: Idea) async throws -> IdeaEntity {
        let ideaEntity = IdeaEntity(context: context)
        ideaEntity.id = idea.id
        ideaEntity.timestamp = idea.timestamp
        ideaEntity.duration = idea.duration
        ideaEntity.transcription = idea.transcription
        ideaEntity.isRecording = idea.isRecording
        ideaEntity.isSynced = idea.isSynced
        
        if let audioURL = idea.audioURL {
            ideaEntity.audioURL = audioURL.absoluteString
            ideaEntity.audioFileName = audioURL.lastPathComponent
        }
        
        try await saveContext()
        return ideaEntity
    }
    
    // MARK: - File Management
    private func saveAudioFile(data: Data, fileName: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        try data.write(to: audioURL)
        return audioURL
    }
    
    func getAudioURL(for fileName: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        return FileManager.default.fileExists(atPath: audioURL.path) ? audioURL : nil
    }
    
    // MARK: - Safe Save Method
    func saveContext() async throws {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
            context.rollback()
            throw error
        }
    }
} 