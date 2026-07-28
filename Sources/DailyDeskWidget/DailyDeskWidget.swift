import SwiftUI
import WidgetKit

@main
struct DailyDeskWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyDeskWidget()
    }
}

struct DailyDeskWidget: Widget {
    let kind = "DailyDeskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyDeskProvider()) { entry in
            DailyDeskWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Nelyr")
        .description("See today’s priorities, focus timer, and shortcut reminders at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DailyDeskEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct DailyDeskProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyDeskEntry {
        DailyDeskEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyDeskEntry) -> Void) {
        completion(DailyDeskEntry(date: Date(), snapshot: WidgetSnapshotStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyDeskEntry>) -> Void) {
        let entry = DailyDeskEntry(date: Date(), snapshot: WidgetSnapshotStore.read())
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct DailyDeskWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyDeskEntry

    var body: some View {
        if family == .systemMedium {
            mediumLayout
        } else {
            smallLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 9) {
            widgetHeader

            if entry.snapshot.priorities.isEmpty {
                Text("Choose what would make today count.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.snapshot.priorities.prefix(2)) { item in
                    priorityRow(item)
                }
                Spacer(minLength: 0)
            }

            Link(destination: URL(string: "nelyr://capture")!) {
                smallShortcutStrip
            }
        }
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            widgetHeader

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("TODAY")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    if entry.snapshot.priorities.isEmpty {
                        Text("Choose what would make today count.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        ForEach(entry.snapshot.priorities.prefix(3)) { item in
                            priorityRow(item)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("SHORTCUTS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    ForEach(entry.snapshot.shortcuts.prefix(5)) { shortcut in
                        HStack(spacing: 8) {
                            Text(shortcut.name)
                    .font(.caption2)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(shortcut.keys)
                                .font(.caption2.monospaced().weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
                .frame(width: 150)
            }
            .frame(maxHeight: .infinity, alignment: .top)

            HStack(spacing: 14) {
                Link(destination: URL(string: "nelyr://capture")!) {
                    Label("Capture", systemImage: "waveform.path.ecg")
                }
                Spacer()
                Link(destination: URL(string: "nelyr://morning")!) {
                    Label("Plan", systemImage: "sunrise.fill")
                }
                Link(destination: URL(string: "nelyr://focus")!) {
                    Label("Focus", systemImage: "timer")
                }
            }
            .font(.caption.weight(.semibold))
        }
    }

    private var widgetHeader: some View {
        HStack {
            Label("Nelyr", systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(NelyrBrand.signalGradient)
            Spacer()
            if entry.snapshot.timerIsRunning {
                Text(entry.snapshot.timerText)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(NelyrBrand.cyan)
            }
        }
    }

    private func priorityRow(_ item: WidgetSnapshot.Item) -> some View {
        HStack(spacing: 7) {
            Button(intent: ToggleWidgetPriorityIntent(priorityID: item.id)) {
                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isComplete ? NelyrBrand.success : Color.secondary)
            }
            .buttonStyle(.plain)
            Text(item.title)
                .font(.caption)
                .lineLimit(1)
                .strikethrough(item.isComplete)
            Spacer(minLength: 2)
            Button(intent: DeleteWidgetPriorityIntent(priorityID: item.id)) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
        }
    }

    private var smallShortcutStrip: some View {
        HStack(spacing: 5) {
            Image(systemName: "waveform.path.ecg")
                .foregroundStyle(NelyrBrand.signalGradient)
            ForEach(entry.snapshot.shortcuts.prefix(3)) { shortcut in
                Text(compactKeys(shortcut.keys))
                    .font(.caption2.monospaced().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if shortcut.id != entry.snapshot.shortcuts.prefix(3).last?.id {
                    Text("·").foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help("Capture · Dictate · Voice Edit")
    }

    private func compactKeys(_ keys: String) -> String {
        keys.replacingOccurrences(of: "Space", with: "␣")
    }
}
