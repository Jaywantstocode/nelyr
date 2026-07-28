import SwiftUI

struct DeskTileView: View {
    @EnvironmentObject private var model: DailyDeskModel
    @EnvironmentObject private var timer: FocusTimer

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                NelyrBrandBadge(size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nelyr").font(.headline)
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ProgressRing(progress: model.progress, size: 44, lineWidth: 5)
            }
            Divider()

            if model.priorities.isEmpty {
                Text("Choose what would make today count.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(model.priorities.prefix(3)) { item in
                    PriorityRow(
                        item: item,
                        compact: true,
                        onToggle: { model.togglePriority(item.id) },
                        onDelete: { model.deletePriority(item.id) }
                    )
                }
            }

            AddField(placeholder: "Add a priority…", icon: "plus", onSubmit: { model.addPriority($0) })

            HStack(spacing: 10) {
                Button { timer.toggle() } label: {
                    Label(timer.isRunning ? timer.formattedTime : "Start focus", systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(NelyrBrand.accent)

                Button { CapturePanelController.shared.show() } label: {
                    Image(systemName: "waveform.path.ecg")
                }
                .buttonStyle(.bordered)
                .help("Capture thought (Control–Option–Space)")
            }
        }
        .padding(18)
        .tint(NelyrBrand.accent)
        .background(NelyrBrand.ambientBackground)
        .background(.regularMaterial)
    }
}
