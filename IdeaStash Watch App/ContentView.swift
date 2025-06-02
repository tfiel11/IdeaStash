//
//  ContentView.swift
//  IdeaStash Watch App
//
//  Created by Tyler Fielding on 5/29/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = IdeaStashViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Recording Section - Full Screen Priority
                    VStack {
                        Spacer()
                        RecordingButton(viewModel: viewModel)
                        Spacer()
                    }
                    .frame(minHeight: WKInterfaceDevice.current().screenBounds.height - 40) // Account for smaller navigation
                    
                    // Recent Ideas Section - Only show when not recording
                    if viewModel.recordingState != .recording && !viewModel.ideas.isEmpty {
                        VStack(spacing: 16) {
                            // Visual separator
                            HStack {
                                VStack {
                                    Divider()
                                }
                                Image(systemName: "chevron.up")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                VStack {
                                    Divider()
                                }
                            }
                            .padding(.horizontal)
                            
                            RecentIdeasSection(ideas: Array(viewModel.ideas.prefix(5)), viewModel: viewModel)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .scrollDisabled(viewModel.recordingState == .recording) // Disable scrolling when recording
            .navigationBarHidden(false) // Keep navigation bar visible for consistent layout
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
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            animationAmount = 1.15
        }
    }
    
    private func stopBreathingAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            animationAmount = 1.0
        }
    }
}

// MARK: - Recent Ideas Section Component
struct RecentIdeasSection: View {
    let ideas: [Idea]
    let viewModel: IdeaStashViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                Text("Recent Ideas")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            
            // Ideas List
            ForEach(ideas) { idea in
                RecentIdeaRow(idea: idea, onDelete: {
                    viewModel.deleteIdea(idea)
                })
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Recent Idea Row Component
struct RecentIdeaRow: View {
    let idea: Idea
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with audio icon and timestamp
            HStack {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(idea.timestamp.relativeTimeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(idea.duration.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Transcription Preview
            if let transcription = idea.transcription {
                Text(transcription)
                    .font(.caption)
                    .lineLimit(3)
                    .foregroundColor(.primary)
            } else {
                Text("Voice Recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

#Preview {
    ContentView()
}
