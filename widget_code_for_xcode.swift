// Bu kodu Xcode'da DotCatWidget/DotCatWidget.swift dosyasına yapıştır

import WidgetKit
import SwiftUI

// Görev modeli
struct TaskItem: Codable, Identifiable {
    let id: String
    let title: String
    let time: String
    let type: String
    let isCompleted: Bool
}

// Widget verisi
struct WidgetEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskItem]
    let catName: String?
    let pendingCount: Int
}

// Veri sağlayıcı
struct Provider: TimelineProvider {
    let appGroupId = "group.com.petcare.dotcat"
    
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), tasks: [], catName: nil, pendingCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        let entry = loadData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> ()) {
        let entry = loadData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadData() -> WidgetEntry {
        let userDefaults = UserDefaults(suiteName: appGroupId)
        
        var tasks: [TaskItem] = []
        if let data = userDefaults?.data(forKey: "widget_tasks"),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = decoded
        }
        
        let catName = userDefaults?.string(forKey: "widget_cat_name")
        let pendingCount = userDefaults?.integer(forKey: "widget_pending_count") ?? 0
        
        return WidgetEntry(
            date: Date(),
            tasks: tasks,
            catName: catName,
            pendingCount: pendingCount
        )
    }
}

// Widget görünümü
struct DotCatWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidget(entry: entry)
        case .systemMedium:
            MediumWidget(entry: entry)
        default:
            SmallWidget(entry: entry)
        }
    }
}

// Küçük widget
struct SmallWidget: View {
    let entry: WidgetEntry
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "pawprint.fill")
                        .font(.title2)
                    Text("dotcat")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                
                Spacer()
                
                if entry.pendingCount > 0 {
                    Text("\(entry.pendingCount)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    Text("bekleyen görev")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Tümü tamam!")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// Orta widget
struct MediumWidget: View {
    let entry: WidgetEntry
    
    var body: some View {
        ZStack {
            Color(hex: "F8F9FA")
            
            HStack(spacing: 16) {
                // Sol kısım - Özet
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "pawprint.fill")
                            .foregroundColor(Color(hex: "6366F1"))
                        Text("dotcat")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    if entry.pendingCount > 0 {
                        Text("\(entry.pendingCount)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(hex: "6366F1"))
                        Text("bekleyen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        Text("Tamam!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: 80)
                
                // Sağ kısım - Görev listesi
                VStack(alignment: .leading, spacing: 6) {
                    if entry.tasks.isEmpty {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack {
                                Image(systemName: "checkmark.circle")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                Text("Bugün görev yok")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        Spacer()
                    } else {
                        ForEach(entry.tasks.prefix(3)) { task in
                            HStack(spacing: 8) {
                                Image(systemName: iconFor(task.type))
                                    .font(.caption)
                                    .foregroundColor(colorFor(task.type))
                                    .frame(width: 16)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(task.title)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    Text(task.time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if task.isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        
                        if entry.tasks.count > 3 {
                            Text("+\(entry.tasks.count - 3) daha")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }
    
    func iconFor(_ type: String) -> String {
        switch type {
        case "vaccine": return "syringe.fill"
        case "medicine": return "pills.fill"
        case "vet": return "cross.fill"
        case "food": return "fork.knife"
        case "grooming": return "scissors"
        default: return "pawprint.fill"
        }
    }
    
    func colorFor(_ type: String) -> Color {
        switch type {
        case "vaccine": return Color(hex: "10B981")
        case "medicine": return Color(hex: "F59E0B")
        case "vet": return Color(hex: "1ABC9C")
        case "food": return Color(hex: "EF4444")
        case "grooming": return Color(hex: "F39C12")
        default: return Color(hex: "6366F1")
        }
    }
}

// Hex renk desteği
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Widget tanımı
@main
struct DotCatWidget: Widget {
    let kind: String = "DotCatWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DotCatWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("dotcat")
        .description("Kedinin bugünkü görevlerini takip et")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

