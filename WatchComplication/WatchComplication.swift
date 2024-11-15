import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entry = SimpleEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct WatchComplicationEntryView : View {
    var entry: SimpleEntry

    var body: some View {
        ZStack(alignment: .center) {
            AccessoryWidgetBackground()
            Image(systemName: "waveform.badge.plus")
                .resizable()
                .scaledToFit()
                .padding()
        }
    }
}

@main
struct WatchComplication: Widget {
    let kind: String = "WatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WatchComplicationEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("App Launcher")
        .description("Quick launch the app")
        .supportedFamilies([.accessoryCircular])
    }
}
