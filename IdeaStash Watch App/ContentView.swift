//
//  ContentView.swift
//  IdeaStash Watch App
//
//  Created by Tyler Fielding on 5/29/25.
//

import SwiftUI
import WatchKit

struct ContentView: View {
    @StateObject private var viewModel = IdeaStashViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Connectivity Status at top
                    HStack {
                        Circle()
                            .fill(viewModel.connectivityStatusColor)
                            .frame(width: 8, height: 8)
                        Text(viewModel.connectivityStatusText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        if viewModel.unsyncedIdeasCount > 0 {
                            Text("\(viewModel.unsyncedIdeasCount) unsynced")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Recording Button - Main interface
                    RecordingButton(viewModel: viewModel)
                        .padding(.horizontal)
                    
                    // Sync button when there are unsynced ideas
                    if viewModel.unsyncedIdeasCount > 0 && viewModel.connectivityManager.isReachable {
                        Button(action: {
                            viewModel.syncWithPhone()
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Sync Now")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Ideas List
                    if !viewModel.ideas.isEmpty {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.ideas) { idea in
                                IdeaRowView(idea: idea, viewModel: viewModel)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("IdeaStash")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onReceive(NotificationCenter.default.publisher(for: .startRecordingFromComplication)) { _ in
            // Handle complication tap - start recording if not already recording
            if viewModel.recordingState == .idle {
                viewModel.toggleRecording()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Recording Button Component
struct RecordingButton: View {
    @ObservedObject var viewModel: IdeaStashViewModel
    @State private var animationAmount: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            // Status Text - Always show, changes based on state
            Text(viewModel.statusText)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Main Recording Button - Larger for prominence
            Button(action: {
                // Haptic feedback
                WKInterfaceDevice.current().play(.start)
                viewModel.toggleRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(viewModel.buttonBackgroundColor)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: viewModel.buttonIcon)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(animationAmount)
            .onChange(of: viewModel.recordingState) { oldValue, newValue in
                // Handle animation based on recording state
                switch newValue {
                case .recording:
                    WKInterfaceDevice.current().play(.start)
                    startBreathingAnimation()
                case .processing:
                    WKInterfaceDevice.current().play(.click)
                    stopBreathingAnimation()
                case .completed:
                    WKInterfaceDevice.current().play(.success)
                    stopBreathingAnimation()
                case .idle:
                    stopBreathingAnimation()
                }
            }
            
            // Fixed space for either timer or arrow - absolutely no movement
            HStack {
                Spacer()
                if viewModel.recordingState == .recording {
                    // Recording duration display
                    Text(viewModel.currentRecordingDuration.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if viewModel.recordingState == .idle && !viewModel.ideas.isEmpty {
                    // Scroll hint arrow
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Invisible placeholder to maintain consistent spacing
                    Text("00:00")
                        .font(.caption)
                        .foregroundColor(.clear)
                }
                Spacer()
            }
            .frame(height: 16) // Fixed height that matches both text and arrow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Prevent any container shifts
    }
    
    private func startBreathingAnimation() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            animationAmount = 1.1
        }
    }
    
    private func stopBreathingAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            animationAmount = 1.0
        }
    }
}

// MARK: - Idea Row Component
struct IdeaRowView: View {
    let idea: Idea
    @ObservedObject var viewModel: IdeaStashViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Duration and timestamp
                    HStack {
                        Text(idea.duration.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(idea.timestamp.relativeTimeString)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Transcription or placeholder
                    if let transcription = idea.transcription, !transcription.isEmpty {
                        Text(transcription)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(3)
                    } else {
                        Text("No transcription")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                
                // Delete button
                Button(action: {
                    viewModel.deleteIdea(idea)
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}
