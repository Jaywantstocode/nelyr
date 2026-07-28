import SwiftUI

struct Card<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(NelyrBrand.violet.opacity(0.15))
            }
            .shadow(color: NelyrBrand.graphite.opacity(0.06), radius: 14, y: 6)
    }
}

struct SectionTitle: View {
    let title: String
    let icon: String
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(NelyrBrand.signalGradient)
            Text(title)
                .font(.headline)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ProgressRing: View {
    let progress: Double
    var size: CGFloat = 48
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, progress))
                .stroke(
                    NelyrBrand.signalAngularGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.45), value: progress)
            Text("\(Int(progress * 100))")
                .font(.system(size: size * 0.24, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Daily progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

struct PriorityRow: View {
    let item: PriorityItem
    let compact: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Button(action: onToggle) {
                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: compact ? 17 : 20, weight: .medium))
                    .foregroundStyle(item.isComplete ? NelyrBrand.success : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isComplete ? "Mark incomplete" : "Mark complete")

            Text(item.title)
                .font(compact ? .callout : .body)
                .strikethrough(item.isComplete)
                .foregroundStyle(item.isComplete ? .secondary : .primary)
                .lineLimit(compact ? 1 : 2)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete priority")
        }
        .contentShape(Rectangle())
    }
}

struct AddField: View {
    let placeholder: String
    let icon: String
    var focusSignal: Notification.Name? = nil
    let onSubmit: (String) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit(submit)
            Button(action: submit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.secondary.opacity(0.35)
                            : NelyrBrand.accent
                    )
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(NelyrBrand.violet.opacity(0.055), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(NelyrBrand.violet.opacity(focused ? 0.38 : 0.10))
        }
        .onReceive(NotificationCenter.default.publisher(for: focusSignal ?? .init("DailyDesk.noop"))) { _ in
            focused = true
        }
    }

    private func submit() {
        let submitted = text
        text = ""
        onSubmit(submitted)
    }
}
