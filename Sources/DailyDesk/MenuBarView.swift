import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: DailyDeskModel
    @EnvironmentObject private var timer: FocusTimer
    @EnvironmentObject private var pipeline: IdeaPipeline
    @EnvironmentObject private var vault: VaultManager
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var research = ResearchController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                NelyrBrandBadge(size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nelyr")
                        .font(.headline)
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ProgressRing(progress: model.progress, size: 40, lineWidth: 4)
                if model.streak > 0 {
                    Label("\(model.streak)", systemImage: "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NelyrBrand.accent)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("TODAY")
                    .font(.caption2.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)

                if model.priorities.isEmpty {
                    Text("No priorities yet. Choose what matters today.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 5)
                } else {
                    ForEach(model.priorities.prefix(4)) { item in
                        PriorityRow(
                            item: item,
                            compact: true,
                            onToggle: { model.togglePriority(item.id) },
                            onDelete: { model.deletePriority(item.id) }
                        )
                    }
                }

                AddField(placeholder: "Add a priority…", icon: "plus", onSubmit: { model.addPriority($0) })
            }

            Button {
                CapturePanelController.shared.show()
            } label: {
                Label("Capture thought", systemImage: "waveform.path.ecg")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(vault.vaultURL == nil)

            if research.isBusy {
                HStack {
                    Label("Grok is researching…", systemImage: "globe.americas.fill")
                        .font(.callout)
                        .foregroundStyle(NelyrBrand.cyan)
                    Spacer()
                    Button("Cancel") { research.cancelResearch() }
                        .buttonStyle(.plain)
                        .font(.caption)
                }
            } else if research.lastResult != nil {
                Button {
                    research.showLastResult()
                } label: {
                    Label("Open last research", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 10) {
                Button {
                    timer.toggle()
                } label: {
                    Label(timer.isRunning ? timer.formattedTime : "Focus", systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(NelyrBrand.accent)

                Button {
                    openWindow(id: "main")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                } label: {
                    Label("Open", systemImage: "rectangle.inset.filled")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 10) {
                Button("Morning plan") {
                    openWindow(id: "morning")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .font(.caption)
                Button("Desk Tile") {
                    openWindow(id: "tile")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .font(.caption)
                Spacer()
                if pipeline.pendingCount > 0 {
                    Text("\(pipeline.pendingCount) pending")
                        .font(.caption2)
                        .foregroundStyle(NelyrBrand.warning)
                }
            }

            HStack {
                Text(timer.isRunning ? "Focus session in progress" : "Everything saves automatically")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 360)
        .tint(NelyrBrand.accent)
        .background(NelyrBrand.ambientBackground)
    }
}
