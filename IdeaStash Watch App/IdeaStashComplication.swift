//
//  IdeaStashComplication.swift
//  IdeaStash Watch App
//
//  Created by Tyler Fielding on 5/29/25.
//

import SwiftUI
import WidgetKit
import CoreData

// MARK: - Complication Entry
struct IdeaEntry: TimelineEntry {
    let date: Date
    let ideaCount: Int
    let latestIdea: String?
    let lastRecordingTime: Date?
}

// MARK: - Complication Timeline Provider
struct IdeaComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> IdeaEntry {
        IdeaEntry(
            date: Date(),
            ideaCount: 5,
            latestIdea: "App idea: Voice recorder for thoughts",
            lastRecordingTime: Date()
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (IdeaEntry) -> Void) {
        let entry = IdeaEntry(
            date: Date(),
            ideaCount: getIdeaCount(),
            latestIdea: getLatestIdea(),
            lastRecordingTime: getLastRecordingTime()
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<IdeaEntry>) -> Void) {
        let currentDate = Date()
        
        // Create entry for now
        let entry = IdeaEntry(
            date: currentDate,
            ideaCount: getIdeaCount(),
            latestIdea: getLatestIdea(),
            lastRecordingTime: getLastRecordingTime()
        )
        
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    // MARK: - Data Helpers
    private func getIdeaCount() -> Int {
        let context = StorageManager.shared.persistentContainer.viewContext
        let request = IdeaEntity.fetchRequest()
        
        do {
            let count = try context.count(for: request)
            return count
        } catch {
            print("Error fetching idea count: \(error)")
            return 0
        }
    }
    
    private func getLatestIdea() -> String? {
        let context = StorageManager.shared.persistentContainer.viewContext
        let request = IdeaEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \IdeaEntity.timestamp, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let ideas = try context.fetch(request)
            return ideas.first?.transcription
        } catch {
            print("Error fetching latest idea: \(error)")
            return nil
        }
    }
    
    private func getLastRecordingTime() -> Date? {
        let context = StorageManager.shared.persistentContainer.viewContext
        let request = IdeaEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \IdeaEntity.timestamp, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let ideas = try context.fetch(request)
            return ideas.first?.timestamp
        } catch {
            print("Error fetching last recording time: \(error)")
            return nil
        }
    }
}

// MARK: - Complication Views
struct IdeaComplicationEntryView: View {
    var entry: IdeaComplicationProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        case .accessoryInline:
            InlineComplicationView(entry: entry)
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        default:
            CircularComplicationView(entry: entry)
        }
    }
}

// MARK: - Circular Complication
struct CircularComplicationView: View {
    let entry: IdeaEntry
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.background)
            
            // Just show the app icon, centered and properly sized
            Image("ComplicationIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .widgetURL(URL(string: "ideastash://record"))
    }
}

// MARK: - Rectangular Complication
struct RectangularComplicationView: View {
    let entry: IdeaEntry
    
    var body: some View {
        HStack(spacing: 8) {
            // App icon on the left
            Image("ComplicationIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(entry.ideaCount) Ideas")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    if let lastTime = entry.lastRecordingTime {
                        Text(lastTime.relativeTimeString)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let latestIdea = entry.latestIdea {
                    Text(latestIdea)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                } else {
                    Text("Tap to record your first idea")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)
        .widgetURL(URL(string: "ideastash://record"))
    }
}

// MARK: - Inline Complication
struct InlineComplicationView: View {
    let entry: IdeaEntry
    
    var body: some View {
        HStack(spacing: 4) {
            Image("ComplicationIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            
            Text("\(entry.ideaCount)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text(entry.ideaCount == 1 ? "idea" : "ideas")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .widgetURL(URL(string: "ideastash://record"))
    }
}

// MARK: - Corner Complication
struct CornerComplicationView: View {
    let entry: IdeaEntry
    
    var body: some View {
        VStack(spacing: 1) {
            Image("ComplicationIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            
            Text("\(entry.ideaCount)")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .widgetURL(URL(string: "ideastash://record"))
    }
}

// MARK: - Widget Configuration
struct IdeaStashComplication: Widget {
    let kind: String = "IdeaStashComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: IdeaComplicationProvider()) { entry in
            IdeaComplicationEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("IdeaStash")
        .description("Quick access to your voice ideas and recording count.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - Preview
#if DEBUG
struct IdeaStashComplication_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            IdeaComplicationEntryView(entry: IdeaEntry(
                date: Date(),
                ideaCount: 7,
                latestIdea: "Remember to call mom about dinner plans this weekend",
                lastRecordingTime: Date()
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            
            IdeaComplicationEntryView(entry: IdeaEntry(
                date: Date(),
                ideaCount: 12,
                latestIdea: "App idea: A voice recorder for capturing thoughts quickly and organizing them",
                lastRecordingTime: Calendar.current.date(byAdding: .hour, value: -2, to: Date())
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            
            IdeaComplicationEntryView(entry: IdeaEntry(
                date: Date(),
                ideaCount: 3,
                latestIdea: "Buy groceries: milk, eggs, bread",
                lastRecordingTime: Calendar.current.date(byAdding: .minute, value: -30, to: Date())
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
            
            // Zero state preview
            IdeaComplicationEntryView(entry: IdeaEntry(
                date: Date(),
                ideaCount: 0,
                latestIdea: nil,
                lastRecordingTime: nil
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
        }
    }
}
#endif 