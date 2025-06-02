//
//  IdeaStashWatchComp.swift
//  IdeaStashWatchComp
//
//  Created by Tyler Fielding on 6/2/25.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), ideaCount: 5)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), ideaCount: getIdeaCount())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate, ideaCount: getIdeaCount())
        
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    // Helper to get idea count (simplified for now)
    private func getIdeaCount() -> Int {
        // This would connect to your shared data in a real implementation
        return 0
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let ideaCount: Int
}

struct IdeaStashWatchCompEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularView()
        case .accessoryRectangular:
            RectangularView(ideaCount: entry.ideaCount)
        case .accessoryInline:
            InlineView(ideaCount: entry.ideaCount)
        default:
            CircularView()
        }
    }
}

// MARK: - Circular Complication (App Icon Only)
struct CircularView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.background)
            
            // App icon centered and properly sized
            Image("AppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .widgetURL(URL(string: "ideastash://record"))
    }
}

// MARK: - Rectangular Complication
struct RectangularView: View {
    let ideaCount: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image("AppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            VStack(alignment: .leading) {
                Text("IdeaStash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text("\(ideaCount) ideas recorded")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .widgetURL(URL(string: "ideastash://record"))
    }
}

// MARK: - Inline Complication
struct InlineView: View {
    let ideaCount: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image("AppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            
            Text("IdeaStash: \(ideaCount)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
        .widgetURL(URL(string: "ideastash://record"))
    }
}

@main
struct IdeaStashWatchComp: Widget {
    let kind: String = "IdeaStashWatchComp"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(watchOS 10.0, *) {
                IdeaStashWatchCompEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                IdeaStashWatchCompEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("IdeaStash")
        .description("Quick access to record voice ideas")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

#Preview(as: .accessoryCircular) {
    IdeaStashWatchComp()
} timeline: {
    SimpleEntry(date: .now, ideaCount: 5)
    SimpleEntry(date: .now, ideaCount: 8)
}
