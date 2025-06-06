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
    // Initialize core services at app launch
    let storageManager = StorageManager.shared
    let connectivityManager = PhoneConnectivityManager.shared
    
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
