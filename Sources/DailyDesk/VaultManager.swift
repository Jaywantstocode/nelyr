import AppKit
import Foundation

@MainActor
final class VaultManager: ObservableObject {
    static let shared = VaultManager()

    @Published private(set) var vaultURL: URL?
    @Published private(set) var lastError: String?

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let vaultPathKey = "DailyDesk.vaultPath"

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
        if let path = defaults.string(forKey: vaultPathKey), !path.isEmpty {
            vaultURL = URL(fileURLWithPath: path, isDirectory: true)
        }
    }

    var ideasDirectory: URL? {
        vaultURL?.appendingPathComponent("Ideas", isDirectory: true)
    }

    var researchDirectory: URL? {
        vaultURL?.appendingPathComponent("Research", isDirectory: true)
    }

    var attachmentsDirectory: URL? {
        vaultURL?.appendingPathComponent("Attachments", isDirectory: true)
    }

    @discardableResult
    func chooseVault() -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Choose or create your Obsidian vault"
        panel.prompt = "Use This Folder"
        panel.message = "Nelyr will store your life captures as Markdown notes in an Ideas folder inside this location."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        setVault(url)
        return true
    }

    func setVault(_ url: URL) {
        vaultURL = url.standardizedFileURL
        defaults.set(vaultURL?.path, forKey: vaultPathKey)
        do {
            try ensureVaultStructure()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func capture(_ raw: String, template: String) throws -> CapturedNote {
        guard let ideasDirectory else { throw VaultError.notConfigured }
        try ensureVaultStructure()
        let id = UUID()
        let createdAt = Date()
        let filename = "Inbox - \(IdeaTemplateRenderer.safeFilename(for: "Idea", createdAt: createdAt, id: id))"
        let url = ideasDirectory.appendingPathComponent(filename)
        let markdown = IdeaTemplateRenderer.renderRaw(
            id: id,
            createdAt: createdAt,
            original: raw,
            captureKind: .text,
            template: template
        )
        try Data(markdown.utf8).write(to: url, options: .atomic)
        let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        return CapturedNote(
            id: id,
            createdAt: createdAt,
            originalText: raw,
            captureKind: .text,
            fileURL: url,
            originalModificationDate: modified
        )
    }

    func captureScreenshot(
        context: String,
        recognizedText: String,
        pngData: Data,
        template: String
    ) throws -> CapturedNote {
        guard let ideasDirectory, let attachmentsDirectory else { throw VaultError.notConfigured }
        try ensureVaultStructure()

        let id = UUID()
        let createdAt = Date()
        let attachmentFilename = Self.screenshotFilename(createdAt: createdAt, id: id)
        let attachmentURL = attachmentsDirectory.appendingPathComponent(attachmentFilename)
        let attachmentReference = "Attachments/\(attachmentFilename)"
        let original = Self.screenshotMarkdown(
            context: context,
            recognizedText: recognizedText,
            attachmentReference: attachmentReference
        )
        let noteFilename = "Inbox - \(IdeaTemplateRenderer.safeFilename(for: "Screenshot", createdAt: createdAt, id: id))"
        let noteURL = ideasDirectory.appendingPathComponent(noteFilename)
        let markdown = IdeaTemplateRenderer.renderRaw(
            id: id,
            createdAt: createdAt,
            original: original,
            captureKind: .screenshot,
            template: template
        )

        do {
            try pngData.write(to: attachmentURL, options: .atomic)
            try Data(markdown.utf8).write(to: noteURL, options: .atomic)
        } catch {
            try? fileManager.removeItem(at: attachmentURL)
            throw error
        }

        let modified = try? noteURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        return CapturedNote(
            id: id,
            createdAt: createdAt,
            originalText: original,
            captureKind: .screenshot,
            fileURL: noteURL,
            originalModificationDate: modified
        )
    }

    func enrich(
        _ note: CapturedNote,
        enrichment: IdeaEnrichment,
        related: [RelatedIdea],
        model: String,
        template: String
    ) throws -> URL {
        guard let ideasDirectory else { throw VaultError.notConfigured }
        let currentModified = try? note.fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        if let original = note.originalModificationDate,
           let current = currentModified,
           abs(original.timeIntervalSince(current)) > 0.5 {
            throw VaultError.noteChangedDuringEnrichment
        }

        let filename = IdeaTemplateRenderer.safeFilename(
            for: enrichment.title,
            createdAt: note.createdAt,
            id: note.id
        )
        let destination = ideasDirectory.appendingPathComponent(filename)
        let markdown = IdeaTemplateRenderer.render(
            id: note.id,
            createdAt: note.createdAt,
            original: note.originalText,
            captureKind: note.captureKind,
            enrichment: enrichment,
            related: related,
            model: model,
            template: template
        )
        try Data(markdown.utf8).write(to: destination, options: .atomic)
        if destination != note.fileURL, fileManager.fileExists(atPath: note.fileURL.path) {
            try fileManager.removeItem(at: note.fileURL)
        }
        return destination
    }

    func saveResearch(
        id: UUID,
        createdAt: Date,
        query: String,
        depth: ResearchDepth,
        response: GrokResearchResponse
    ) throws -> URL {
        guard let researchDirectory else { throw VaultError.notConfigured }
        try ensureVaultStructure()
        let filename = IdeaTemplateRenderer.safeFilename(
            for: "Research - \(query)",
            createdAt: createdAt,
            id: id
        )
        let url = researchDirectory.appendingPathComponent(filename)
        let sessionID = response.sessionID.map(Self.escapeYAML) ?? ""
        let requestID = response.requestID.map(Self.escapeYAML) ?? ""
        let markdown = """
        ---
        id: "\(id.uuidString.lowercased())"
        created: \(ISO8601DateFormatter().string(from: createdAt))
        type: research
        depth: \(depth.rawValue)
        source: daily-desk
        research_provider: grok-cli
        research_model: grok-4.5
        session_id: "\(sessionID)"
        request_id: "\(requestID)"
        tags:
          - research
        ---

        ## Original question

        \(query.trimmingCharacters(in: .whitespacesAndNewlines))

        \(response.markdown.trimmingCharacters(in: .whitespacesAndNewlines))

        ## Usage

        - Mode: \(depth.title)
        - Turns: \(response.usage.turns.map(String.init) ?? "Not reported")
        - Total tokens: \(response.usage.totalTokens.map(String.init) ?? "Not reported")
        - Reported cost (USD): \(response.usage.costUSD.map { String(format: "%.4f", $0) } ?? "Not reported for OAuth usage")
        """ + "\n"
        try Data(markdown.utf8).write(to: url, options: .atomic)
        return url
    }

    func scanNotes(excluding excludedURL: URL? = nil) throws -> [VaultNote] {
        guard let vaultURL else { throw VaultError.notConfigured }
        guard fileManager.fileExists(atPath: vaultURL.path) else { throw VaultError.vaultMissing }
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .isHiddenKey]
        guard let enumerator = fileManager.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var notes: [VaultNote] = []
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "md" {
            if url.standardizedFileURL == excludedURL?.standardizedFileURL { continue }
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true,
                  let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) else { continue }
            let title = Self.extractTitle(from: text) ?? url.deletingPathExtension().lastPathComponent
            notes.append(VaultNote(
                fileURL: url,
                title: title,
                linkName: url.deletingPathExtension().lastPathComponent,
                searchableText: String(text.prefix(8_000)),
                modifiedAt: values?.contentModificationDate ?? .distantPast
            ))
        }
        return notes
    }

    private func ensureVaultStructure() throws {
        guard let vaultURL, let ideasDirectory, let researchDirectory, let attachmentsDirectory else {
            throw VaultError.notConfigured
        }
        try fileManager.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: ideasDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: researchDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
    }

    private static func screenshotMarkdown(
        context: String,
        recognizedText: String,
        attachmentReference: String
    ) -> String {
        var sections: [String] = []
        let context = context.trimmingCharacters(in: .whitespacesAndNewlines)
        let recognizedText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !context.isEmpty { sections.append(context) }
        sections.append("### Screenshot\n\n![[\(attachmentReference)]]")
        sections.append(
            "### Extracted text\n\n" + (recognizedText.isEmpty ? "No readable text was recognized." : recognizedText)
        )
        return sections.joined(separator: "\n\n")
    }

    private static func screenshotFilename(createdAt: Date, id: UUID) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "Screenshot-\(formatter.string(from: createdAt))-\(id.uuidString.prefix(6).lowercased()).png"
    }

    private static func escapeYAML(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func extractTitle(from markdown: String) -> String? {
        markdown.split(separator: "\n", omittingEmptySubsequences: false)
            .first { $0.hasPrefix("# ") }
            .map { String($0.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

enum VaultError: LocalizedError {
    case notConfigured
    case vaultMissing
    case noteChangedDuringEnrichment

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Choose an Obsidian vault before capturing thoughts."
        case .vaultMissing: return "The selected Obsidian vault could not be found."
        case .noteChangedDuringEnrichment: return "The raw note changed while AI enrichment was running, so it was not overwritten."
        }
    }
}
