import AppKit
import SwiftUI
import UniformTypeIdentifiers

private struct ScreenshotDraft: Equatable {
    let pngData: Data
    var recognizedText: String
}

struct QuickCaptureView: View {
    @State private var text: String
    @State private var screenshot: ScreenshotDraft?
    @State private var isProcessingScreenshot = false
    @State private var screenshotError: String?
    @State private var isImageDropTargeted = false
    @State private var showImagePicker = false
    @State private var importToken = UUID()
    @FocusState private var focused: Bool
    @ObservedObject private var vault = VaultManager.shared
    @ObservedObject private var pipeline = IdeaPipeline.shared
    @ObservedObject private var voice = VoiceDictationController.shared

    init(initialText: String = "") {
        _text = State(initialValue: initialText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            contextEditor
            screenshotArea
            if screenshot != nil {
                recognizedTextEditor
            }
            footer
        }
        .padding(20)
        .tint(NelyrBrand.accent)
        .background(.regularMaterial)
        .background(NelyrBrand.ambientBackground)
        .onAppear { focused = true }
        .onChange(of: screenshot != nil) { _, expanded in
            CapturePanelController.shared.setScreenshotExpanded(expanded)
        }
        .onDrop(of: [.image], isTargeted: $isImageDropTargeted, perform: importImageProviders)
        .onPasteCommand(of: [.image]) { providers in
            _ = importImageProviders(providers)
        }
        .fileImporter(
            isPresented: $showImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { importImageFile(url) }
            case .failure(let error):
                screenshotError = error.localizedDescription
            }
        }
    }

    private var header: some View {
        HStack {
            Label(
                screenshot == nil ? "Capture a thought" : "Capture a screenshot",
                systemImage: screenshot == nil ? "waveform.path.ecg" : "text.viewfinder"
            )
                .font(.headline)
                .foregroundStyle(NelyrBrand.signalGradient)
            Spacer()
            if let language = voice.lastDetectedLanguage {
                Text(language.uppercased())
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text("⌃⌥Space")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var contextEditor: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(screenshot == nil ? "What’s on your mind?" : "Add context or why this matters…")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .focused($focused)
        }
        .padding(7)
        .frame(height: screenshot == nil ? 100 : 74)
        .background(.quaternary.opacity(0.42), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var screenshotArea: some View {
        if let screenshot, let preview = NSImage(data: screenshot.pngData) {
            HStack(spacing: 12) {
                Image(nsImage: preview)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 116, height: 82)
                    .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Label("Screenshot ready", systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(NelyrBrand.success)
                    Text(screenshot.recognizedText.isEmpty ? "No text found — you can type it below." : "OCR completed locally with Apple Vision.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button("Replace…") { showImagePicker = true }
                            .buttonStyle(.link)
                        Button("Remove", role: .destructive) { removeScreenshot() }
                            .buttonStyle(.link)
                    }
                    .font(.caption)
                }
                Spacer()
            }
            .padding(10)
            .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            HStack(spacing: 11) {
                Image(systemName: "photo.badge.plus")
                    .font(.title3)
                    .foregroundStyle(isImageDropTargeted ? NelyrBrand.accent : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isProcessingScreenshot ? "Reading screenshot…" : "Drop a screenshot here")
                        .font(.callout.weight(.medium))
                    Text("PNG, JPEG, HEIC, or TIFF · OCR stays on this Mac")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isProcessingScreenshot {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Choose…") { showImagePicker = true }
                    Button("Paste image") { pasteImageFromClipboard() }
                        .help("Paste an image from the clipboard")
                }
            }
            .padding(12)
            .background(
                isImageDropTargeted ? NelyrBrand.violet.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isImageDropTargeted ? NelyrBrand.accent : Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            }

            if let screenshotError {
                Label(screenshotError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(NelyrBrand.warning)
                    .textSelection(.enabled)
            }
        }
    }

    private var recognizedTextEditor: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label("Extracted text", systemImage: "text.viewfinder")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("Editable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            TextEditor(text: Binding(
                get: { screenshot?.recognizedText ?? "" },
                set: { screenshot?.recognizedText = $0 }
            ))
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(7)
            .frame(minHeight: 130)
            .background(.quaternary.opacity(0.42), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var footer: some View {
        HStack {
            Button {
                toggleVoice()
            } label: {
                Label(
                    quickVoiceIsRecording ? "Stop" : "Speak",
                    systemImage: quickVoiceIsRecording ? "stop.circle.fill" : "mic.circle.fill"
                )
            }
            .buttonStyle(.bordered)
            .tint(quickVoiceIsRecording ? NelyrBrand.danger : NelyrBrand.accent)
            .disabled(voice.state.isBusy && !quickVoiceIsRecording)
            .help(settingsVoiceHelp)

            if vault.vaultURL == nil {
                Button("Choose Obsidian vault") { _ = vault.chooseVault() }
                    .buttonStyle(.link)
                Text("Required for Markdown capture")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label(statusText, systemImage: statusIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel") { CapturePanelController.shared.close() }
                .keyboardShortcut(.cancelAction)
            Button(screenshot == nil ? "Save thought" : "Save screenshot") { submit() }
                .buttonStyle(.borderedProminent)
                .tint(NelyrBrand.accent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(saveDisabled)
        }
    }

    private var saveDisabled: Bool {
        if vault.vaultURL == nil || isProcessingScreenshot { return true }
        return screenshot == nil && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var quickVoiceIsRecording: Bool {
        voice.activeDestination == .quickCapture && voice.isRecording
    }

    private var settingsVoiceHelp: String {
        DailyDeskSettings.shared.isWhisperModelInstalled
            ? "Transcribe English or Japanese locally"
            : "Install the local model in Settings → Voice first"
    }

    private func toggleVoice() {
        if quickVoiceIsRecording {
            Task {
                if let result = await voice.finishQuickCapture() {
                    if !text.isEmpty, !text.hasSuffix(" ") { text += " " }
                    text += result.text
                    focused = true
                }
            }
        } else {
            Task { await voice.beginQuickCapture() }
        }
    }

    private var statusText: String {
        pipeline.ollamaAvailable ? "Saved first, enriched locally afterward" : "Saved now; AI retries when Ollama is ready"
    }

    private var statusIcon: String {
        pipeline.ollamaAvailable ? "lock.shield.fill" : "exclamationmark.circle"
    }

    private func importImageProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { provider in
            provider.registeredTypeIdentifiers.contains { identifier in
                UTType(identifier)?.conforms(to: .image) == true
            }
        }) else {
            screenshotError = "The dropped item is not a supported image."
            return false
        }
        let identifier = provider.registeredTypeIdentifiers.first {
            UTType($0)?.conforms(to: .image) == true
        } ?? UTType.image.identifier
        provider.loadDataRepresentation(forTypeIdentifier: identifier) { data, error in
            Task { @MainActor in
                if let data {
                    importImageData(data)
                } else {
                    screenshotError = error?.localizedDescription ?? "Nelyr could not read that image."
                }
            }
        }
        return true
    }

    private func importImageFile(_ url: URL) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            try importImageData(Data(contentsOf: url))
        } catch {
            screenshotError = error.localizedDescription
        }
    }

    private func pasteImageFromClipboard() {
        let pasteboard = NSPasteboard.general
        let imageTypes = [UTType.png, .tiff, .jpeg, .heic]
        for type in imageTypes {
            if let data = pasteboard.data(forType: .init(type.identifier)) {
                importImageData(data)
                return
            }
        }
        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingContentsConformToTypes: [UTType.image.identifier]]
        ) as? [URL], let url = urls.first {
            importImageFile(url)
            return
        }
        screenshotError = "No image is currently on the clipboard."
    }

    private func importImageData(_ data: Data) {
        let token = UUID()
        importToken = token
        screenshot = nil
        screenshotError = nil
        isProcessingScreenshot = true
        Task {
            do {
                let processed = try await ScreenshotOCRService.shared.process(data)
                guard importToken == token else { return }
                screenshot = ScreenshotDraft(
                    pngData: processed.pngData,
                    recognizedText: processed.recognizedText
                )
                if processed.recognizedText.isEmpty {
                    screenshotError = "No readable text was found. You can still add context and save the image."
                }
            } catch {
                guard importToken == token else { return }
                screenshotError = error.localizedDescription
            }
            if importToken == token { isProcessingScreenshot = false }
        }
    }

    private func removeScreenshot() {
        importToken = UUID()
        screenshot = nil
        screenshotError = nil
        isProcessingScreenshot = false
    }

    private func submit() {
        let saved: Bool
        if let screenshot {
            saved = DailyDeskModel.shared.captureScreenshot(
                context: text,
                recognizedText: screenshot.recognizedText,
                pngData: screenshot.pngData
            )
        } else {
            saved = DailyDeskModel.shared.captureIdea(text)
        }
        guard saved else { return }
        text = ""
        removeScreenshot()
        CapturePanelController.shared.close()
    }
}
