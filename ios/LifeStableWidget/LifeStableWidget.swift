import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), tasksCount: 0, activeHabitsCount: 0, nextTaskTitle: "Next up: None")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), tasksCount: 3, activeHabitsCount: 2, nextTaskTitle: "Next up: Read Book")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.ahmettunakuran.lifestable")
        
        let tasksCount = userDefaults?.integer(forKey: "tasks_count") ?? 0
        let activeHabitsCount = userDefaults?.integer(forKey: "active_habits_count") ?? 0
        let tasksJsonStr = userDefaults?.string(forKey: "tasks_data") ?? "[]"
        
        var nextTaskTitle = "Next up: None"
        if let data = tasksJsonStr.data(using: .utf8) {
            do {
                if let tasksArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    for task in tasksArray {
                        if let isDone = task["isDone"] as? Bool, !isDone,
                           let title = task["title"] as? String {
                            nextTaskTitle = "Next up: \(title)"
                            break
                        }
                    }
                }
            } catch {
                print("Failed to decode tasks JSON")
            }
        }
        
        let entry = SimpleEntry(date: Date(), tasksCount: tasksCount, activeHabitsCount: activeHabitsCount, nextTaskTitle: nextTaskTitle)
        
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let tasksCount: Int
    let activeHabitsCount: Int
    let nextTaskTitle: String
}

struct LifeStableWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LifeStable")
                .font(.headline)
                .foregroundColor(Color(red: 255/255, green: 179/255, blue: 0/255))
            
            Text("Pending Tasks: \(entry.tasksCount)")
                .font(.subheadline)
                .foregroundColor(.white)
            
            Text("Active Habits: \(entry.activeHabitsCount)")
                .font(.subheadline)
                .foregroundColor(.white)
            
            Text(entry.nextTaskTitle)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 26/255, green: 18/255, blue: 0/255))
    }
}

@main
struct LifeStableWidget: Widget {
    let kind: String = "LifeStableWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LifeStableWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("LifeStable Overview")
        .description("Shows your pending tasks and active habits.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
