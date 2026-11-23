// Bojang streak widget (plan #25), WidgetKit.
//
// NOT IN THE XCODE PROJECT YET. Adding the extension needs a new App ID, the
// App Group and a provisioning profile in CI; see docs/IOS_WIDGET_SETUP.md.
//
// Reads what lib/services/home_widget_sync.dart writes with home_widget into
// the App Group defaults (keys in lib/utils/widget_snapshot.dart): streak,
// streak_state, last_done_date, word_*, and line_day / line_evening /
// line_late / line_last_call / line_done. The part of day and "done today"
// are worked out here from the clock, so the widget changes through the day
// between app opens.

import SwiftUI
import WidgetKit

let appGroup = "group.com.bojang.app.widget"

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let state: String  // none / active / frozen / earn_back
    let doneToday: Bool
    let headline: String
    let wordTibetan: String
    let wordMeaning: String
}

enum DayPart: String {
    case day, evening, late, last_call

    static func at(_ date: Date) -> DayPart {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<16: return .day
        case 16..<20: return .evening
        case 20..<22: return .late
        default: return .last_call
        }
    }
}

struct StreakProvider: TimelineProvider {
    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    private static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func entry(at date: Date) -> StreakEntry {
        let d = defaults
        let today = Self.dayFormat.string(from: date)
        let done = d?.string(forKey: "last_done_date") == today
        let part = DayPart.at(date)
        let headline = d?.string(forKey: done ? "line_done" : "line_\(part.rawValue)")
            ?? "Open Bojang to start your streak"
        let phonetic = d?.string(forKey: "word_phonetic") ?? ""
        let english = d?.string(forKey: "word_english") ?? ""
        return StreakEntry(
            date: date,
            streak: d?.integer(forKey: "streak") ?? 0,
            state: d?.string(forKey: "streak_state") ?? "none",
            doneToday: done,
            headline: headline,
            wordTibetan: d?.string(forKey: "word_tibetan") ?? "",
            wordMeaning: phonetic.isEmpty ? english : "\(phonetic) · \(english)"
        )
    }

    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), streak: 7, state: "active", doneToday: false,
                    headline: "7 days and counting", wordTibetan: "གཡག",
                    wordMeaning: "yak · yak")
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: Date()))
    }

    /// One entry per part-of-day boundary (4 pm, 8 pm, 10 pm, midnight), so
    /// the headline moves on without the app.
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let now = Date()
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        var dates = [now]
        for hour in [16, 20, 22, 24] {
            if let d = cal.date(byAdding: .hour, value: hour, to: start), d > now {
                dates.append(d)
            }
        }
        completion(Timeline(entries: dates.map(entry(at:)), policy: .atEnd))
    }
}

struct BojangWidgetView: View {
    let entry: StreakEntry
    @Environment(\.widgetFamily) private var family

    private var symbol: String {
        if entry.state == "frozen" && !entry.doneToday { return "snowflake" }
        return "flame.fill"
    }

    private var tint: Color {
        if entry.state == "frozen" && !entry.doneToday { return Color(red: 0.13, green: 0.45, blue: 0.78) }
        if entry.doneToday || (entry.state == "active" && entry.streak > 0) {
            return Color(red: 0.76, green: 0.33, blue: 0.05)
        }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: symbol).font(.system(size: 30)).foregroundStyle(tint)
                if entry.doneToday {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.12, green: 0.52, blue: 0.31))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.streak)").font(.system(size: 26, weight: .bold))
                Text(entry.headline).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            if family != .systemSmall {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.wordTibetan).font(.title3)
                    Text(entry.wordMeaning).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .widgetBackground()
    }
}

extension View {
    /// containerBackground on iOS 17+, plain padding before.
    @ViewBuilder func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(.background, for: .widget)
        } else {
            self.padding()
        }
    }
}

@main
struct BojangStreakWidget: Widget {
    // Must match HomeWidgetSync.iosWidgetKind.
    let kind = "BojangStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            BojangWidgetView(entry: entry)
        }
        .configurationDisplayName("Bojang streak")
        .description("Your streak and a Tibetan word every day.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
