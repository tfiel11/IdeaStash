//
//  ContentView.swift
//  IdeaStash Watch App
//
//  Created by Tyler Fielding on 5/29/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var dataProvider = DummyDataProvider()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Recording Section - Full Screen Priority
                    VStack {
                        Spacer()
                        RecordingButton(dataProvider: dataProvider)
                        Spacer()
                    }
                    .frame(minHeight: WKInterfaceDevice.current().screenBounds.height - 40) // Account for smaller navigation
                    
                    // Recent Ideas Section - Accessible via scroll
                    if !dataProvider.ideas.isEmpty {
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
                            
                            RecentIdeasSection(ideas: Array(dataProvider.ideas.prefix(5)))
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Recording Button Component
struct RecordingButton: View {
    @ObservedObject var dataProvider: DummyDataProvider
    @State private var animationAmount: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            // Status Text - Always show, changes based on state
            Text(statusText)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Main Recording Button - Larger for prominence
            Button(action: {
                // Haptic feedback
                WKInterfaceDevice.current().play(.start)
                dataProvider.toggleRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(buttonBackgroundColor)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: buttonIcon)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(buttonForegroundColor)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(animationAmount)
            .onChange(of: dataProvider.recordingState) { oldValue, newValue in
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
            
            // Scroll hint - maintain consistent spacing
            VStack(spacing: 4) {
                if dataProvider.recordingState == .idle && !dataProvider.ideas.isEmpty {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Invisible placeholder to maintain layout consistency
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundColor(.clear)
                }
            }
            .padding(.top, 8)
        }
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
    
    private var buttonBackgroundColor: Color {
        switch dataProvider.recordingState {
        case .idle, .completed:
            return Color(red: 216/255, green: 211/255, blue: 191/255) // #D8D3BF - Original beige
        case .recording:
            return Color(red: 212/255, green: 165/255, blue: 165/255) // #D4A5A5 - Soft coral red
        case .processing:
            return Color(red: 212/255, green: 200/255, blue: 154/255) // #D4C89A - Warm amber
        }
    }
    
    private var buttonForegroundColor: Color {
        .white
    }
    
    private var buttonIcon: String {
        switch dataProvider.recordingState {
        case .idle, .completed:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        case .processing:
            return "ellipsis"
        }
    }
    
    private var statusText: String {
        switch dataProvider.recordingState {
        case .idle:
            return "Tap to Stash Idea"
        case .recording:
            return "Stashing Idea"
        case .processing:
            return "Processing..."
        case .completed:
            return "Saved!"
        }
    }
}

// MARK: - Recent Ideas Section Component
struct RecentIdeasSection: View {
    let ideas: [Idea]
    
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
                RecentIdeaRow(idea: idea)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Recent Idea Row Component
struct RecentIdeaRow: View {
    let idea: Idea
    
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
    }
}

#Preview {
    ContentView()
}
