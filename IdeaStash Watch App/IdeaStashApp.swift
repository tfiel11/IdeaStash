//
//  IdeaStashApp.swift
//  IdeaStash Watch App
//
//  Created by Tyler Fielding on 5/29/25.
//

import SwiftUI
import WidgetKit

@main
struct IdeaStash_Watch_AppApp: App {
    
    // Initialize the storage manager and connectivity at app launch
    let storageManager = StorageManager.shared
    let connectivityManager = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, storageManager.persistentContainer.viewContext)
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }
    
    // MARK: - URL Handling
    private func handleURL(_ url: URL) {
        // Handle deep links from complications
        if url.scheme == "ideastash" {
            switch url.host {
            case "record":
                // Post notification to trigger recording
                NotificationCenter.default.post(name: .startRecordingFromComplication, object: nil)
            default:
                break
            }
        }
    }
}

// MARK: - Widget Bundle
struct IdeaStashWidgetBundle: WidgetBundle {
    var body: some Widget {
        IdeaStashComplication()
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let startRecordingFromComplication = Notification.Name("startRecordingFromComplication")
}
