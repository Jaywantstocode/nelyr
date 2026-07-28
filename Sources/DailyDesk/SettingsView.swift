import AppKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var settings: DailyDeskSettings
    @EnvironmentObject private var pipeline: IdeaPipeline
    @EnvironmentObject private var vault: VaultManager
    @EnvironmentObject private var notifications: NotificationService
    @ObservedObject private var launchAtLogin = LaunchAtLoginService.shared
    @ObservedObject private var voice = VoiceDictationController.shared
    @ObservedObject private var research = ResearchController.shared
    @ObservedObject private var history = DictationHistoryStore.shared
    @ObservedObject private var dictionary = PersonalDictionaryStore.shared
    @State private var dictionaryTerm = ""
    @State private var dictionarySearch = ""
    @State private var historySearch = ""
    @State private var microphoneTestResult: String?
    @State private var microphoneTestRunning = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            aiTab
                .tabItem { Label("Local AI", systemImage: "cpu") }
            voiceTab
                .tabItem { Label("Voice", systemImage: "waveform") }
            historyTab
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            dictionaryTab
                .tabItem { Label("Dictionary", systemImage: "text.book.closed") }
            templateTab
                .tabItem { Label("Template", systemImage: "doc.text") }
        }
        .tint(NelyrBrand.accent)
        .padding(20)
        .frame(width: 760, height: 640)
        .task {
            await pipeline.checkOllama()
            await notifications.refreshStatus()
        }
    }

    private var generalTab: some View {
        Form {
            Section("Obsidian") {
                LabeledContent("Vault") {
                    Text(vault.vaultURL?.path ?? "Not selected")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(vault.vaultURL == nil ? .secondary : .primary)
                }
                HStack {
                    Button(vault.vaultURL == nil ? "Choose vault…" : "Change vault…") {
                        _ = vault.chooseVault()
                    }
                    if let url = vault.vaultURL {
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    }
                }
            }

            Section("Capture") {
                LabeledContent("Global shortcut", value: "Control–Option–Space")
                LabeledContent("Selected text", value: "Right-click → Services")
                Toggle("Launch Nelyr at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                Text("The shortcut opens capture over any app. To save highlighted text without opening the capture window, choose Services → Save Selection to Nelyr. Neither action requires Accessibility access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = launchAtLogin.lastError {
                    Text(error).font(.caption).foregroundStyle(NelyrBrand.warning)
                }
            }

            Section("Shortcut reminder") {
                shortcutRow("Capture a thought", keys: "⌃⌥Space", icon: "waveform.path.ecg")
                shortcutRow("Dictate anywhere", keys: settings.voiceDictationShortcut.symbols, icon: "waveform")
                shortcutRow("Voice-edit selection", keys: settings.voiceEditShortcut.symbols, icon: "text.cursor")
                shortcutRow("Translate while dictating", keys: settings.translationDictationShortcut.symbols, icon: "character.bubble")
                shortcutRow("Voice web research", keys: settings.researchDictationShortcut.symbols, icon: "globe.americas.fill")
                shortcutRow("Save highlighted text", keys: "Right-click → Services", icon: "text.badge.plus")
                Text("The medium Nelyr desktop widget also shows your current shortcuts. Right-click the desktop, choose Edit Widgets, then add Nelyr.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                DatePicker(
                    "Morning reminder",
                    selection: morningTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                HStack {
                    Text(notificationStatusText)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if notifications.authorizationStatus == .notDetermined {
                        Button("Allow notifications") {
                            Task { await notifications.requestAuthorization() }
                        }
                    } else {
                        Button("Update schedule") {
                            Task { await notifications.scheduleMorningReminder() }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var voiceTab: some View {
        Form {
            Section("Local Whisper model") {
                Picker("Recognition model", selection: $settings.whisperModel) {
                    Text("Large v3 compressed · best accuracy · ~626 MB")
                        .tag("large-v3-v20240930_626MB")
                    Text("Small multilingual · faster download")
                        .tag("small")
                    Text("Base multilingual · lightweight")
                        .tag("base")
                }
                HStack {
                    Label(
                        settings.isWhisperModelInstalled ? "Installed and private" : "Not installed",
                        systemImage: settings.isWhisperModelInstalled ? "checkmark.circle.fill" : "arrow.down.circle"
                    )
                    .foregroundStyle(settings.isWhisperModelInstalled ? NelyrBrand.success : Color.secondary)
                    Spacer()
                    Button(settings.isWhisperModelInstalled ? "Reinstall model" : "Install model") {
                        Task { await voice.installModel() }
                    }
                    .disabled(voice.state.isBusy)
                }
                if case .preparingModel(let progress) = voice.state {
                    VStack(alignment: .leading, spacing: 5) {
                        ProgressView(value: progress ?? voice.downloadProgress)
                        Text(progress == nil ? "Loading Core ML model…" : "Downloading and preparing on this Mac…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("The model is downloaded once from Argmax/Hugging Face, then English and Japanese transcription runs entirely on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Microphone") {
                Picker("Input", selection: $settings.microphoneDeviceID) {
                    Text("System default").tag(UInt32(0))
                    ForEach(WhisperAudioRecorder.inputDevices, id: \.id) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                HStack {
                    Button(microphoneTestRunning ? "Listening…" : "Test microphone") {
                        microphoneTestRunning = true
                        microphoneTestResult = nil
                        Task {
                            let heardAudio = await WhisperAudioRecorder.testInput(deviceID: settings.microphoneDeviceID)
                            microphoneTestResult = heardAudio ? "Microphone sounds good" : "No voice detected"
                            microphoneTestRunning = false
                        }
                    }
                    .disabled(microphoneTestRunning || voice.isRecording)
                    if let microphoneTestResult {
                        Label(
                            microphoneTestResult,
                            systemImage: microphoneTestResult == "Microphone sounds good" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(
                            microphoneTestResult == "Microphone sounds good"
                                ? NelyrBrand.success
                                : NelyrBrand.warning
                        )
                    }
                }
            }

            Section("Dictation") {
                Picker("Shortcut behavior", selection: $settings.voiceActivationMode) {
                    ForEach(VoiceActivationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(voice.state.isBusy)
                Text(settings.voiceActivationMode.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Shortcut", selection: $settings.voiceDictationShortcut) {
                    ForEach(VoiceDictationShortcut.allCases) { shortcut in
                        Text(shortcut.title).tag(shortcut)
                    }
                }
                .disabled(voice.state.isBusy)
                Picker("Cleanup", selection: $settings.voiceCleanupMode) {
                    ForEach(VoiceCleanupMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Text(settings.voiceCleanupMode.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Paste directly into the active app", isOn: $settings.directVoiceInsertion)
                HStack {
                    Label(
                        voice.isAccessibilityTrusted ? "Accessibility allowed" : "Clipboard fallback active",
                        systemImage: voice.isAccessibilityTrusted ? "checkmark.shield.fill" : "doc.on.clipboard"
                    )
                    .foregroundStyle(voice.isAccessibilityTrusted ? NelyrBrand.success : Color.secondary)
                    Spacer()
                    if !voice.isAccessibilityTrusted {
                        Button("Allow Accessibility…") { voice.requestAccessibility() }
                    }
                }
                Text("Use \(settings.voiceDictationShortcut.title) to dictate. The shortcut and activation style change immediately. Without Accessibility permission, Nelyr copies the result so you can press Command–V yourself.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Writing intelligence") {
                Toggle("Adapt formatting to the active app", isOn: $settings.appAwareDictation)
                Toggle("Play start and stop sounds", isOn: $settings.interactionSounds)
                TextField("Optional writing style (e.g. concise, casual, no em dashes)", text: $settings.customWritingStyle)
                Text("Nelyr distinguishes chat, email, coding tools, and documents locally. Your dictionary and style stay on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Translate") {
                Picker("Target language", selection: $settings.translationTarget) {
                    ForEach(TranslationTarget.allCases) { target in Text(target.title).tag(target) }
                }
                Picker("Shortcut", selection: $settings.translationDictationShortcut) {
                    ForEach(TranslationDictationShortcut.allCases) { shortcut in Text(shortcut.title).tag(shortcut) }
                }
                Text("Press once, speak naturally, then press again. Translation runs through your local Ollama model.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Voice Edit") {
                Picker("Shortcut", selection: $settings.voiceEditShortcut) {
                    ForEach(VoiceEditShortcut.allCases) { shortcut in Text(shortcut.title).tag(shortcut) }
                }
                Text("Select editable text in any app, press once, say an instruction such as “make this warmer,” then press again. Accessibility permission is required.")
                    .font(.caption).foregroundStyle(.secondary)
            }


            Section("Grok voice research") {
                Picker("Research depth", selection: $settings.researchDepth) {
                    ForEach(ResearchDepth.allCases) { depth in
                        Text(depth.title).tag(depth)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(research.isBusy || voice.state.isBusy)
                Text(settings.researchDepth.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Research shortcut", selection: $settings.researchDictationShortcut) {
                    ForEach(ResearchDictationShortcut.allCases) { shortcut in
                        Text(shortcut.title).tag(shortcut)
                    }
                }
                .disabled(research.isBusy || voice.state.isBusy)

                HStack {
                    Label(
                        research.isGrokInstalled ? "Grok CLI found" : "Grok CLI not found",
                        systemImage: research.isGrokInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(
                        research.isGrokInstalled
                            ? NelyrBrand.success
                            : NelyrBrand.warning
                    )
                    Spacer()
                    if research.lastResult != nil {
                        Button("Open last research") { research.showLastResult() }
                    }
                }

                Text("Use \(settings.researchDictationShortcut.title) to record a question. Only research recordings are sent through your existing Grok login. Web search and page fetching are allowed; MCP tools, shell commands, local file tools, memory, and subagents are explicitly denied. Results are saved in your Obsidian Research folder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if research.isBusy {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Research in progress…")
                        Spacer()
                        Button("Cancel") { research.cancelResearch() }
                    }
                }
            }

            Section("Privacy") {
                Picker("Local dictation history", selection: $settings.voiceHistoryRetention) {
                    ForEach(VoiceHistoryRetention.allCases) { retention in
                        Text(retention.title).tag(retention)
                    }
                }
                Label("Audio stays in memory and is discarded after transcription.", systemImage: "lock.shield")
                Label("Ollama cleanup stays local and falls back to the raw transcript.", systemImage: "desktopcomputer")
            }

            if case .failed(let message) = voice.state {
                Text(message).font(.callout).foregroundStyle(NelyrBrand.warning)
            }
            if case .failed(let message) = research.state {
                Text(message).font(.callout).foregroundStyle(NelyrBrand.warning)
            }
        }
        .formStyle(.grouped)
    }

    private var historyTab: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                statistic("Words", value: historyWordCount.formatted(), icon: "text.word.spacing")
                statistic("Time spoken", value: formattedMinutes(historyDuration), icon: "waveform")
                statistic("Est. time saved", value: formattedMinutes(historyTimeSaved), icon: "clock.badge.checkmark")
            }
            HStack {
                TextField("Search dictation history", text: $historySearch)
                    .textFieldStyle(.roundedBorder)
                Picker("Keep", selection: $settings.voiceHistoryRetention) {
                    ForEach(VoiceHistoryRetention.allCases) { Text($0.title).tag($0) }
                }
                .frame(width: 180)
                Button("Delete All", role: .destructive) { history.deleteAll() }
                    .disabled(history.items.isEmpty)
            }
            if filteredHistory.isEmpty {
                ContentUnavailableView(
                    "No dictation history",
                    systemImage: "clock",
                    description: Text("Dictation, translation, and Voice Edit results will appear here.")
                )
            } else {
                List(filteredHistory) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(item.mode.title, systemImage: historyIcon(item.mode))
                                .font(.caption.weight(.semibold))
                            Text(item.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                            Text(item.createdAt, style: .time).font(.caption).foregroundStyle(.secondary)
                            if let app = item.appContext.appName {
                                Text(app).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { copy(item.outputText) } label: { Image(systemName: "doc.on.doc") }
                                .buttonStyle(.borderless).help("Copy")
                            Button(role: .destructive) { history.delete(item.id) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless).help("Delete")
                        }
                        Text(item.outputText).textSelection(.enabled).lineLimit(4)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
    }

    private var dictionaryTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Names, products, acronyms, and uncommon spellings are supplied to local AI as exact hints.")
                .foregroundStyle(.secondary)
            HStack {
                TextField("Add a word or phrase", text: $dictionaryTerm)
                    .onSubmit { addDictionaryTerm() }
                Button("Add") { addDictionaryTerm() }.disabled(dictionaryTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Import CSV…") { importDictionaryCSV() }
            }
            TextField("Search dictionary", text: $dictionarySearch)
                .textFieldStyle(.roundedBorder)
            if filteredDictionary.isEmpty {
                ContentUnavailableView("No dictionary entries", systemImage: "text.book.closed")
            } else {
                List(filteredDictionary) { entry in
                    HStack {
                        Text(entry.term).textSelection(.enabled)
                        Spacer()
                        Button(role: .destructive) { dictionary.delete(entry.id) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var filteredHistory: [DictationHistoryItem] {
        guard !historySearch.isEmpty else { return history.items }
        return history.items.filter {
            $0.outputText.localizedCaseInsensitiveContains(historySearch)
                || $0.rawText.localizedCaseInsensitiveContains(historySearch)
                || ($0.appContext.appName?.localizedCaseInsensitiveContains(historySearch) == true)
        }
    }

    private var historyWordCount: Int {
        history.items.reduce(0) { $0 + $1.outputText.split(whereSeparator: \.isWhitespace).count }
    }

    private var historyDuration: TimeInterval {
        history.items.reduce(0) { $0 + $1.duration }
    }

    private var historyTimeSaved: TimeInterval {
        max(0, Double(historyWordCount) / 40 * 60 - historyDuration)
    }

    private func formattedMinutes(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "<1 min" }
        return "\(Int(seconds / 60).formatted()) min"
    }

    private func statistic(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(NelyrBrand.signalGradient)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(NelyrBrand.violet.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private var filteredDictionary: [PersonalDictionaryEntry] {
        guard !dictionarySearch.isEmpty else { return dictionary.entries }
        return dictionary.entries.filter { $0.term.localizedCaseInsensitiveContains(dictionarySearch) }
    }

    private func addDictionaryTerm() {
        if dictionary.add(dictionaryTerm) { dictionaryTerm = "" }
    }

    private func importDictionaryCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        _ = dictionary.importCSV(from: url)
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func historyIcon(_ mode: DictationHistoryItem.Mode) -> String {
        switch mode {
        case .dictation: "waveform"
        case .translation: "character.bubble"
        case .voiceEdit: "text.cursor"
        }
    }

    private var aiTab: some View {
        Form {
            Section("Ollama") {
                HStack {
                    Label(
                        pipeline.ollamaAvailable ? "Ollama is running" : "Ollama is unavailable",
                        systemImage: pipeline.ollamaAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(
                        pipeline.ollamaAvailable
                            ? NelyrBrand.success
                            : NelyrBrand.warning
                    )
                    Spacer()
                    Button("Check again") { Task { await pipeline.checkOllama() } }
                }
                TextField("Generation model", text: $settings.generationModel)
                TextField("Embedding model", text: $settings.embeddingModel)
                Button("Install required models") {
                    Task { await pipeline.installRequiredModels() }
                }
                .disabled(isInstalling)
                if isInstalling {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Downloading \(installingModel)… This can take several minutes.")
                            .font(.caption)
                    }
                }
            }

            Section("Enrichment instructions") {
                Text("Each capture receives one type (idea, goal, reflection, memory, learning, or question), one to three life areas, and a few specific topic tags.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $settings.customAIInstructions)
                    .font(.body)
                    .frame(minHeight: 120)
                Text("These instructions are sent only to your local Ollama model.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if case .failed(let message) = pipeline.phase {
                Text(message)
                    .foregroundStyle(NelyrBrand.warning)
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
    }

    private var templateTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Obsidian Markdown template").font(.headline)
                    Text("Required placeholders protect the original capture and metadata structure.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Restore default") { settings.restoreDefaultTemplate() }
            }
            TextEditor(text: $settings.noteTemplate)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            Label(
                IdeaTemplateRenderer.isValidTemplate(settings.noteTemplate)
                    ? "Template is valid"
                    : "Missing a required placeholder; the last valid template will be used",
                systemImage: IdeaTemplateRenderer.isValidTemplate(settings.noteTemplate)
                    ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(
                IdeaTemplateRenderer.isValidTemplate(settings.noteTemplate)
                    ? NelyrBrand.success
                    : NelyrBrand.warning
            )
        }
    }

    private var morningTimeBinding: Binding<Date> {
        Binding {
            Calendar.current.date(from: DateComponents(hour: settings.morningHour, minute: settings.morningMinute)) ?? Date()
        } set: { date in
            settings.morningHour = Calendar.current.component(.hour, from: date)
            settings.morningMinute = Calendar.current.component(.minute, from: date)
        }
    }

    private func shortcutRow(_ name: String, keys: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(NelyrBrand.signalGradient)
                .frame(width: 18)
            Text(name)
            Spacer()
            Text(keys)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private var notificationStatusText: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional: return "Notifications enabled"
        case .denied: return "Notifications disabled in System Settings"
        case .notDetermined: return "Permission not requested"
        @unknown default: return "Unknown permission state"
        }
    }

    private var isInstalling: Bool {
        if case .installing = pipeline.phase { return true }
        return false
    }

    private var installingModel: String {
        if case .installing(let model) = pipeline.phase { return model }
        return "models"
    }
}
