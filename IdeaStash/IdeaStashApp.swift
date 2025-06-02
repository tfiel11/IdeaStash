//
//  IdeaStashApp.swift
//  IdeaStash
//
//  Created by Tyler Fielding on 5/29/25.
//

import SwiftUI
import UserNotifications

@main
struct IdeaStashApp: App {
    // Initialize storage manager to set up Core Data
    @StateObject private var storageManager = StorageManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, storageManager.persistentContainer.viewContext)
                .onAppear {
                    // Request notification permissions for transcription status
                    requestNotificationPermissions()
                }
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
}
