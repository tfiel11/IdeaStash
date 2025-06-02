//
//  IdeaStashApp.swift
//  IdeaStash Watch App
//
//  Created by Tyler Fielding on 5/29/25.
//

import SwiftUI

@main
struct IdeaStash_Watch_AppApp: App {
    
    // Initialize the storage manager at app launch
    let storageManager = StorageManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, storageManager.persistentContainer.viewContext)
        }
    }
}
