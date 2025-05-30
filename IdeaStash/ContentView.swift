//
//  ContentView.swift
//  IdeaStash
//
//  Created by Tyler Fielding on 5/29/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var dataProvider = DummyDataProvider()
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                if dataProvider.ideas.isEmpty {
                    EmptyStateView()
                } else {
                    IdeasListView(
                        ideas: filteredIdeas,
                        dataProvider: dataProvider
                    )
                }
            }
            .navigationTitle("Stashed Ideas")
            .searchable(text: $searchText, prompt: "Search your ideas...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Sort by Date") { }
                        Button("Sort by Duration") { }
                        Divider()
                        Button("Export All") { }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private var filteredIdeas: [Idea] {
        if searchText.isEmpty {
            return dataProvider.ideas
        } else {
            return dataProvider.ideas.filter { idea in
                idea.transcription?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Ideas Yet")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("Use your Apple Watch to start recording your brilliant ideas")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
}

// MARK: - Ideas List View
struct IdeasListView: View {
    let ideas: [Idea]
    @ObservedObject var dataProvider: DummyDataProvider
    
    var body: some View {
        List {
            ForEach(ideas) { idea in
                IdeaRowView(idea: idea)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .onDelete(perform: deleteIdeas)
        }
        .listStyle(PlainListStyle())
    }
    
    private func deleteIdeas(offsets: IndexSet) {
        // For now, just remove from the dummy data
        // In Phase 2, this will actually delete from storage
        withAnimation {
            dataProvider.ideas.remove(atOffsets: offsets)
        }
    }
}

// MARK: - Idea Row View
struct IdeaRowView: View {
    let idea: Idea
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with timestamp and duration
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(idea.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        Text(idea.duration.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button(action: {
                        // Play audio - will implement in Phase 2
                    }) {
                        Image(systemName: "play.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        // Share - will implement in Phase 2
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Transcription content
            if let transcription = idea.transcription {
                VStack(alignment: .leading, spacing: 8) {
                    Text(transcription)
                        .font(.body)
                        .lineLimit(isExpanded ? nil : 3)
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    
                    if transcription.count > 150 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        }) {
                            Text(isExpanded ? "Show Less" : "Show More")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            } else {
                HStack {
                    Image(systemName: "waveform.path")
                        .foregroundColor(.secondary)
                    Text("Tap play to hear recording")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            if idea.transcription?.count ?? 0 > 150 {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
