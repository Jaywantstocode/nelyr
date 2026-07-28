import AppKit
import SwiftUI

@MainActor
final class VoiceStatusPanelController: VoiceStatusPresenting {
    static let shared = VoiceStatusPanelController()

    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show() {
        hideTask?.cancel()
        if panel == nil { panel = makePanel() }
        positionPanel()
        panel?.orderFrontRegardless()
    }

    func hide(after delay: TimeInterval = 0) {
        hideTask?.cancel()
        guard delay > 0 else {
            panel?.orderOut(nil)
            return
        }
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.panel?.orderOut(nil)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 58),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: VoiceStatusView())
        return panel
    }

    private func positionPanel() {
        guard let panel, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - panel.frame.width / 2,
            y: frame.minY + 54
        ))
    }
}

private struct VoiceStatusView: View {
    @ObservedObject private var voice = VoiceDictationController.shared
    @ObservedObject private var settings = DailyDeskSettings.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .symbolEffect(.pulse, isActive: voice.isRecording)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold))
                if case .preparingModel(let progress?) = voice.state {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(NelyrBrand.accent)
                } else if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(width: 340, height: 58)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(NelyrBrand.violet.opacity(0.24)))
    }

    private var title: String {
        switch voice.state {
        case .idle: "Voice ready"
        case .needsModel: "Install the voice model"
        case .preparingModel(let progress): progress == nil ? "Loading local model…" : "Installing local model…"
        case .recording:
            if voice.activeDestination == .research {
                settings.voiceActivationMode == .hold
                    ? "Research question… release to search"
                    : "Research question… press again to search"
            } else if voice.activeDestination == .translation {
                "Translating to \(settings.translationTarget.title)… press again to finish"
            } else if voice.activeDestination == .voiceEdit {
                "Voice Edit… say how to rewrite it"
            } else {
                settings.voiceActivationMode == .hold
                    ? "Listening… release to finish"
                    : "Listening… press again to finish"
            }
        case .transcribing: "Transcribing locally…"
        case .cleaning:
            voice.activeDestination == .translation ? "Translating with local Ollama…" : "Editing with local Ollama…"
        case .inserting: "Inserting…"
        case .copied: "Copied — press Command–V"
        case .completed: "Done"
        case .failed: "Voice dictation needs attention"
        }
    }

    private var subtitle: String? {
        switch voice.state {
        case .needsModel: "Open Nelyr → Settings → Voice"
        case .recording:
            switch voice.activeDestination {
            case .research: "Only this recording will be sent to Grok"
            case .translation: "Speech recognition stays local"
            case .voiceEdit: "The selected text and instruction stay local"
            default: "100+ languages are detected automatically"
            }
        case .failed(let message): message
        default: nil
        }
    }

    private var icon: String {
        switch voice.state {
        case .recording: "waveform.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .copied: "doc.on.clipboard.fill"
        case .failed, .needsModel: "exclamationmark.triangle.fill"
        default: "waveform"
        }
    }

    private var tint: Color {
        switch voice.state {
        case .recording: NelyrBrand.danger
        case .completed: NelyrBrand.success
        case .failed, .needsModel: NelyrBrand.warning
        default: NelyrBrand.accent
        }
    }
}
