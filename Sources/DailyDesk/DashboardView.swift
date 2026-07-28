import AppKit
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: DailyDeskModel
    @EnvironmentObject private var timer: FocusTimer
    @EnvironmentObject private var pipeline: IdeaPipeline
    @EnvironmentObject private var vault: VaultManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ZStack {
            NelyrBrand.ambientBackground
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    if vault.vaultURL == nil || pipeline.phase != .idle {
                        statusBanner
                    }
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        prioritiesCard
                        focusCard
                        scratchpadCard
                        captureCard
                    }
                }
                .padding(26)
            }
        }
        .tint(NelyrBrand.accent)
        .preferredColorScheme(nil)
        .onReceive(NotificationCenter.default.publisher(for: .openMorningPlan)) { _ in
            openWindow(id: "morning")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .onOpenURL { url in
            switch url.host {
            case "capture": CapturePanelController.shared.show()
            case "morning":
                openWindow(id: "morning")
                NSApplication.shared.activate(ignoringOtherApps: true)
            case "focus": timer.start()
            default: break
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            NelyrBrandBadge(size: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text("Nelyr")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("\(greeting) · \(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                openWindow(id: "morning")
            } label: {
                Label("Plan", systemImage: "sunrise.fill")
            }
            .buttonStyle(.bordered)
            Button {
                openWindow(id: "tile")
            } label: {
                Label("Desk Tile", systemImage: "rectangle.on.rectangle")
            }
            .buttonStyle(.bordered)
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.bordered)
            if model.streak > 0 {
                Label("\(model.streak) day streak", systemImage: "flame.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NelyrBrand.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(NelyrBrand.violet.opacity(0.10), in: Capsule())
            }
            ProgressRing(progress: model.progress, size: 58, lineWidth: 7)
        }
        .padding(.horizontal, 4)
    }

    private var prioritiesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(
                    title: "Today’s priorities",
                    icon: "checklist",
                    trailing: model.priorities.isEmpty ? "Keep it focused" : "\(model.completedCount)/\(model.priorities.count) done"
                )

                if model.priorities.isEmpty {
                    EmptyState(
                        icon: "sparkles",
                        title: "What would make today count?",
                        detail: "Add up to three outcomes you want to finish."
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(model.priorities) { item in
                            PriorityRow(
                                item: item,
                                compact: false,
                                onToggle: { model.togglePriority(item.id) },
                                onDelete: { model.deletePriority(item.id) }
                            )
                            if item.id != model.priorities.last?.id { Divider() }
                        }
                    }
                }

                AddField(
                    placeholder: "Add a priority…",
                    icon: "plus",
                    focusSignal: .focusPriorityField,
                    onSubmit: { model.addPriority($0) }
                )

                if model.completedCount > 0 {
                    Button("Clear completed") { model.clearCompleted() }
                        .buttonStyle(.link)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var focusCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(title: "Focus", icon: "timer", trailing: "25 minute session")

                HStack(spacing: 20) {
                    ZStack {
                        Circle().stroke(.quaternary, lineWidth: 9)
                        Circle()
                            .trim(from: 0, to: max(0, timer.progress))
                            .stroke(NelyrBrand.signalGradient, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.25), value: timer.progress)
                        VStack(spacing: 1) {
                            Text(timer.formattedTime)
                                .font(.system(size: 23, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text(timer.isRunning ? "FOCUSING" : "READY")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 112, height: 112)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(timer.isRunning ? "One thing at a time." : "Protect a small block of attention.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button(timer.isRunning ? "Pause" : "Start") { timer.toggle() }
                                .buttonStyle(.borderedProminent)
                                .tint(NelyrBrand.accent)
                            Button("Reset") { timer.reset() }
                                .buttonStyle(.bordered)
                        }
                        if timer.completedSessions > 0 {
                            Label("\(timer.completedSessions) today", systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(NelyrBrand.success)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var scratchpadCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Scratchpad", icon: "pencil.line", trailing: "Clears each new day")
                ZStack(alignment: .topLeading) {
                    if model.scratchpad.isEmpty {
                        Text("Notes, rough thinking, a phone number…")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: Binding(
                        get: { model.scratchpad },
                        set: { newValue in model.updateScratchpad(newValue) }
                    ))
                    .font(.body)
                    .scrollContentBackground(.hidden)
                }
                .frame(minHeight: 150)
                .padding(7)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var captureCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 13) {
                SectionTitle(title: "Quick capture", icon: "tray.and.arrow.down", trailing: "Life notes to revisit")
                AddField(placeholder: "Capture a thought…", icon: "waveform.path.ecg", onSubmit: { model.captureIdea($0) })

                if model.captures.isEmpty {
                    EmptyState(icon: "tray", title: "Inbox zero", detail: "Drop distracting thoughts here and keep moving.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(model.captures.prefix(5)) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(NelyrBrand.cyan.opacity(0.72))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 7)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.text)
                                        .font(.callout)
                                        .lineLimit(2)
                                    Text(item.createdAt, style: .time)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Button { model.deleteCapture(item.id) } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete capture")
                            }
                            .padding(.vertical, 8)
                            if item.id != model.captures.prefix(5).last?.id { Divider() }
                        }
                    }
                }
            }
        }
    }

    private var statusBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle).font(.callout.weight(.semibold))
                Text(statusDetail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if vault.vaultURL == nil {
                Button("Choose vault…") { _ = vault.chooseVault() }
                    .buttonStyle(.borderedProminent)
                    .tint(NelyrBrand.accent)
            } else if pipeline.pendingCount > 0 {
                Button("Retry") { pipeline.retryPending() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(statusColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var statusTitle: String {
        if vault.vaultURL == nil { return "Connect your Obsidian vault" }
        switch pipeline.phase {
        case .idle: return "Life captures are ready"
        case .needsVault: return "Choose an Obsidian vault"
        case .checkingOllama: return "Checking local AI"
        case .installing(let model): return "Installing \(model)"
        case .processing: return "Enriching your thought locally"
        case .completed(let title): return "Saved “\(title)”"
        case .failed: return "Thought saved; enrichment needs attention"
        }
    }

    private var statusDetail: String {
        if vault.vaultURL == nil { return "Captured thoughts will become categorized Markdown notes in an Ideas folder." }
        switch pipeline.phase {
        case .failed(let message): return message
        case .processing: return "The raw Markdown is already safe. Ollama is adding type, life areas, meaning, tags, and links."
        case .installing: return "The model stays entirely on this Mac."
        default: return "Control–Option–Space captures a thought from anywhere."
        }
    }

    private var statusIcon: String {
        if vault.vaultURL == nil { return "folder.badge.plus" }
        switch pipeline.phase {
        case .failed: return "exclamationmark.triangle.fill"
        case .processing, .checkingOllama, .installing: return "sparkles"
        case .completed: return "checkmark.circle.fill"
        default: return "lock.shield.fill"
        }
    }

    private var statusColor: Color {
        if vault.vaultURL == nil { return NelyrBrand.warning }
        if case .failed = pipeline.phase { return NelyrBrand.warning }
        return NelyrBrand.success
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

private struct EmptyState: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(NelyrBrand.signalGradient)
                .frame(width: 34, height: 34)
                .background(NelyrBrand.violet.opacity(0.09), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5)
    }
}
