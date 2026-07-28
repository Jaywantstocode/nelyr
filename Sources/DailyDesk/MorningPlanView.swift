import SwiftUI

struct MorningPlanView: View {
    @EnvironmentObject private var model: DailyDeskModel
    @EnvironmentObject private var timer: FocusTimer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Make today intentional")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Choose a few outcomes. You can adjust the plan when reality changes.")
                    .foregroundStyle(.secondary)
            }

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle(title: "Today’s priorities", icon: "sunrise.fill", trailing: "Aim for three")
                    if model.priorities.isEmpty {
                        Text("Start with the one outcome that would make the day feel worthwhile.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.priorities) { item in
                        PriorityRow(
                            item: item,
                            compact: false,
                            onToggle: { model.togglePriority(item.id) },
                            onDelete: { model.deletePriority(item.id) }
                        )
                    }
                    AddField(placeholder: "Add an outcome…", icon: "plus", onSubmit: { model.addPriority($0) })
                }
            }

            HStack {
                Text("Unfinished priorities carry forward automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done planning") { dismiss() }
                Button("Start first focus") {
                    timer.start()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(NelyrBrand.accent)
                .disabled(model.openPriorityCount == 0)
            }
        }
        .padding(26)
        .tint(NelyrBrand.accent)
        .frame(minWidth: 620, minHeight: 470)
        .background(
            NelyrBrand.ambientBackground
        )
    }
}
