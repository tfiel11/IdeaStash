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
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data error: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    private var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    private init() {}
    
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
        idea.setValue(audioURL.absoluteString, forKey: "audioURL")
        
        try context.save()
        return idea
    }
    
    func loadIdeas() async throws -> [IdeaEntity] {
        let request: NSFetchRequest<IdeaEntity> = IdeaEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \IdeaEntity.timestamp, ascending: false)]
        
        return try context.fetch(request)
    }
    
    func deleteIdea(_ idea: IdeaEntity) async throws {
        // Delete audio file if it exists
        if let audioURLString = idea.value(forKey: "audioURL") as? String,
           let audioURL = URL(string: audioURLString) {
            try? FileManager.default.removeItem(at: audioURL)
        }
        
        context.delete(idea)
        try context.save()
    }
    
    func updateIdeaTranscription(_ idea: IdeaEntity, transcription: String) async throws {
        idea.transcription = transcription
        try context.save()
    }
    
    func getUnsyncedIdeas() async throws -> [IdeaEntity] {
        let request: NSFetchRequest<IdeaEntity> = IdeaEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isSynced == false")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \IdeaEntity.timestamp, ascending: false)]
        
        return try context.fetch(request)
    }
    
    func markAsSynced(_ idea: IdeaEntity) async throws {
        idea.isSynced = true
        try context.save()
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
} 