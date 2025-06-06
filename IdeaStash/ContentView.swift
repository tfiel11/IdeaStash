//
//  ContentView.swift
//  IdeaStash
//
//  Created by Tyler Fielding on 5/29/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = IdeaStashViewModel()
    @StateObject private var audioPlayer = AudioPlayer.shared
    @State private var searchText = ""
    @State private var showingBatchTranscriptionSheet = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading {
                    LoadingView()
                } else if viewModel.ideas.isEmpty {
                    EmptyStateView()
                } else {
                    IdeasListView(
                        ideas: filteredIdeas,
                        viewModel: viewModel,
                        audioPlayer: audioPlayer
                    )
                }
            }
            .navigationTitle("Stashed Ideas")
            .searchable(text: $searchText, prompt: "Search your ideas...")
            .refreshable {
                viewModel.refreshIdeas()
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Debug button (for development)
                    Button("Debug") {
                        viewModel.debugAllIdeas()
                    }
                    
                    // Transcribe button - only show if there are untranscribed ideas
                    if viewModel.hasUntranscribedIdeas() {
                        Button {
                            showingBatchTranscriptionSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "text.quote")
                                Text("\(viewModel.getUntranscribedCount())")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    
                    Menu {
                        Button("Sort by Date") { }
                        Button("Sort by Duration") { }
                        Divider()
                        if viewModel.hasUntranscribedIdeas() {
                            Button("Transcribe All") {
                                viewModel.transcribeAllIdeas()
                            }
                            Divider()
                        }
                        Button("Export All") { }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        // Transcription progress overlay
        .overlay {
            if viewModel.isTranscribing {
                TranscriptionProgressView(
                    progress: viewModel.transcriptionProgress,
                    onCancel: {
                        viewModel.cancelTranscription()
                    }
                )
            }
        }
        // Error handling
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        // Permission alert
        .alert("Speech Recognition Permission", isPresented: $viewModel.showingPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.dismissPermissionAlert()
            }
        } message: {
            Text("Speech recognition permission is required to transcribe your voice recordings. You can enable this in Settings.")
        }
        // Batch transcription sheet
        .sheet(isPresented: $showingBatchTranscriptionSheet) {
            BatchTranscriptionSheet(viewModel: viewModel)
        }
    }
    
    private var filteredIdeas: [IdeaEntity] {
        if searchText.isEmpty {
            return viewModel.ideas
        } else {
            return viewModel.ideas.filter { idea in
                idea.transcription?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading your ideas...")
                .foregroundColor(.secondary)
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
    let ideas: [IdeaEntity]
    @ObservedObject var viewModel: IdeaStashViewModel
    @ObservedObject var audioPlayer: AudioPlayer
    
    var body: some View {
        List {
            ForEach(ideas, id: \.objectID) { idea in
                IdeaRowView(idea: idea, viewModel: viewModel, audioPlayer: audioPlayer)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .onDelete(perform: deleteIdeas)
        }
        .listStyle(PlainListStyle())
    }
    
    private func deleteIdeas(offsets: IndexSet) {
        viewModel.deleteIdeas(at: offsets)
    }
}

// MARK: - Idea Row View
struct IdeaRowView: View {
    let idea: IdeaEntity
    @ObservedObject var viewModel: IdeaStashViewModel
    @ObservedObject var audioPlayer: AudioPlayer
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with timestamp and duration
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(idea.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "")
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
                    // Play/Pause button
                    Button(action: {
                        viewModel.togglePlayback(for: idea)
                    }) {
                        Image(systemName: viewModel.isPlayingAudio(for: idea) ? "pause.circle.fill" : "play.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    // Transcribe button - only show if not transcribed or has placeholder
                    if shouldShowTranscribeButton(for: idea) {
                        Button(action: {
                            viewModel.transcribeIdea(idea)
                        }) {
                            Image(systemName: "text.quote")
                                .font(.title3)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Share button
                    Button(action: {
                        // Share functionality - will implement later
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Audio playback progress (if playing this audio)
            if viewModel.isPlayingAudio(for: idea) && audioPlayer.duration > 0 {
                VStack(spacing: 4) {
                    ProgressView(value: audioPlayer.playbackProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    
                    HStack {
                        Text(audioPlayer.currentTime.formattedDuration)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(audioPlayer.duration.formattedDuration)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Transcription content
            if let transcription = idea.transcription, !transcription.contains("Recording audio...") {
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
                    
                    if idea.transcription?.contains("Recording audio...") == true {
                        Text("Tap transcribe to convert to text")
                            .font(.body)
                            .foregroundColor(.orange)
                            .italic()
                    } else {
                        Text("Tap play to hear recording")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            if let transcription = idea.transcription, transcription.count > 150, !transcription.contains("Recording audio...") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
    }
    
    private func shouldShowTranscribeButton(for idea: IdeaEntity) -> Bool {
        return idea.transcription == nil || idea.transcription?.contains("Recording audio...") == true
    }
}

// MARK: - Transcription Progress View
struct TranscriptionProgressView: View {
    let progress: Double
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Transcribing Audio...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 200)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.red)
            }
            .padding(30)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - Batch Transcription Sheet
struct BatchTranscriptionSheet: View {
    @ObservedObject var viewModel: IdeaStashViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Transcribe Recordings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Convert \(viewModel.getUntranscribedCount()) voice recording\(viewModel.getUntranscribedCount() == 1 ? "" : "s") to text using speech recognition.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Works offline")
                            .font(.body)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Processes all recordings automatically")
                            .font(.body)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Makes your ideas searchable")
                            .font(.body)
                        Spacer()
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    viewModel.transcribeAllIdeas()
                    dismiss()
                }) {
                    Text("Start Transcription")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Transcription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
