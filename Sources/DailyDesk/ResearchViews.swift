import AppKit
import SwiftUI

@MainActor
final class ResearchStatusPanelController: ResearchStatusPresenting {
    static let shared = ResearchStatusPanelController()

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
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 64),
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
        panel.contentView = NSHostingView(rootView: ResearchStatusView())
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

@MainActor
protocol ResearchStatusPresenting: AnyObject {
    func show()
    func hide(after delay: TimeInterval)
}

@MainActor
final class ResearchResultPanelController {
    static let shared = ResearchResultPanelController()
    private var panel: NSPanel?

    func show() {
        if panel == nil { panel = makePanel() }
        panel?.center()
        panel?.orderFrontRegardless()
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 720),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Nelyr Research"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 640, height: 480)
        panel.contentView = NSHostingView(rootView: ResearchResultView())
        return panel
    }
}

private struct ResearchStatusView: View {
    @ObservedObject private var research = ResearchController.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .symbolEffect(.pulse, isActive: research.isBusy)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if research.isBusy { ProgressView().controlSize(.small) }
        }
        .padding(.horizontal, 16)
        .frame(width: 360, height: 64)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(NelyrBrand.violet.opacity(0.24)))
    }

    private var title: String {
        switch research.state {
        case .idle: "Research ready"
        case .researching(.starting): "Starting Grok…"
        case .researching(.searching): "Searching and checking sources…"
        case .researching(.writing): "Writing the research note…"
        case .researching(.saving): "Saving to Obsidian…"
        case .completed: "Research saved"
        case .failed: "Research needs attention"
        }
    }

    private var subtitle: String {
        switch research.state {
        case .researching(.writing(_, let count)): "Streaming answer · \(count.formatted()) characters"
        case .failed(let message): message
        case .completed: "Open the result from the menu bar"
        default: research.currentQuery.isEmpty ? "Web research through Grok" : research.currentQuery
        }
    }

    private var icon: String {
        switch research.state {
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        default: "globe.americas.fill"
        }
    }

    private var tint: Color {
        switch research.state {
        case .completed: NelyrBrand.success
        case .failed: NelyrBrand.warning
        default: NelyrBrand.cyan
        }
    }
}

private struct ResearchResultView: View {
    @ObservedObject private var research = ResearchController.shared
    @State private var followsStream = true

    private let bottomAnchor = "research-stream-bottom"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 640, minHeight: 480)
        .tint(NelyrBrand.accent)
        .background(.regularMaterial)
        .background(NelyrBrand.ambientBackground)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: research.isBusy ? "dot.radiowaves.left.and.right" : "globe.americas.fill")
                .font(.title2)
                .foregroundStyle(NelyrBrand.signalGradient)
                .symbolEffect(.pulse, isActive: research.isBusy)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(displayDepth.title).font(.headline)
                    if research.isBusy {
                        Text("LIVE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(NelyrBrand.danger, in: Capsule())
                    }
                }
                Text(displayQuery)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 12)
            if research.isBusy {
                ProgressView().controlSize(.small)
                Text(progressLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 17)
    }

    @ViewBuilder
    private var content: some View {
        if research.isBusy || (!research.liveMarkdown.isEmpty && failedMessage != nil) {
            liveContent
        } else if let result = research.lastResult {
            ScrollView {
                MarkdownDocumentView(markdown: result.markdown)
                    .frame(maxWidth: 820, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 26)
            }
            .textSelection(.enabled)
        } else if let failedMessage {
            ContentUnavailableView(
                "Research failed",
                systemImage: "exclamationmark.triangle",
                description: Text(failedMessage)
            )
        } else {
            ContentUnavailableView(
                "No research yet",
                systemImage: "globe.americas",
                description: Text("Use the research dictation shortcut to ask a question.")
            )
        }
    }

    private var liveContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let failedMessage {
                        Label(failedMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(NelyrBrand.warning)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(NelyrBrand.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                    if research.liveMarkdown.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("Grok is searching and checking sources…")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text(research.liveMarkdown)
                            .font(.system(size: 15, design: .monospaced))
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    Color.clear.frame(height: 1).id(bottomAnchor)
                }
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 28)
                .padding(.vertical, 26)
            }
            .onChange(of: research.liveMarkdown.count) { _, _ in
                guard followsStream else { return }
                proxy.scrollTo(bottomAnchor, anchor: .bottom)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if research.isBusy {
                Toggle("Follow stream", isOn: $followsStream)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Text(characterCountLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                if !research.liveMarkdown.isEmpty {
                    Button("Copy so far") { copy(research.liveMarkdown) }
                }
                Button("Cancel", role: .destructive) { research.cancelResearch() }
            } else if let result = research.lastResult {
                if let total = result.usage.totalTokens {
                    Text("\(abbreviated(total)) tokens")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .help("\(total.formatted()) total tokens")
                }
                if let turns = result.usage.turns {
                    Text("· \(turns) turns")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Copy") { copy(result.markdown) }
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([result.fileURL])
                }
                Button("Open in Obsidian") {
                    NSWorkspace.shared.open(result.fileURL)
                }
                .buttonStyle(.borderedProminent)
                .tint(NelyrBrand.accent)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var displayDepth: ResearchDepth {
        research.isBusy || failedMessage != nil ? research.activeDepth : research.lastResult?.depth ?? research.activeDepth
    }

    private var displayQuery: String {
        if research.isBusy || failedMessage != nil { return research.currentQuery }
        return research.lastResult?.query ?? "Ask with your research shortcut"
    }

    private var failedMessage: String? {
        if case .failed(let message) = research.state { return message }
        return nil
    }

    private var progressLabel: String {
        switch research.state {
        case .researching(.starting): "Starting…"
        case .researching(.searching): "Searching…"
        case .researching(.writing): "Writing…"
        case .researching(.saving): "Saving…"
        default: "Working…"
        }
    }

    private var characterCountLabel: String {
        "\(research.liveMarkdown.count.formatted()) characters"
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func abbreviated(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fk", Double(value) / 1_000)
        }
        return value.formatted()
    }
}

private struct MarkdownDocumentView: View {
    let markdown: String

    private var blocks: [MarkdownBlock] { MarkdownBlockParser.parse(markdown) }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            InlineMarkdownText(text: text)
                .font(headingFont(level))
                .padding(.top, level == 1 ? 4 : 10)
        case .paragraph(let text):
            InlineMarkdownText(text: text)
                .font(.system(size: 16))
                .lineSpacing(5)
        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(.secondary)
                        InlineMarkdownText(text: item)
                            .font(.system(size: 16))
                            .lineSpacing(4)
                    }
                }
            }
            .padding(.leading, 4)
        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 22, alignment: .trailing)
                        InlineMarkdownText(text: item)
                            .font(.system(size: 16))
                            .lineSpacing(4)
                    }
                }
            }
        case .quote(let text):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(NelyrBrand.cyan.opacity(0.62))
                    .frame(width: 3)
                InlineMarkdownText(text: text)
                    .font(.system(size: 16).italic())
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
            }
            .padding(.vertical, 4)
        case .code(let language, let text):
            VStack(alignment: .leading, spacing: 8) {
                if let language {
                    Text(language.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ScrollView(.horizontal) {
                    Text(text)
                        .font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        case .table(let headers, let rows):
            MarkdownTableView(headers: headers, rows: rows)
        case .rule:
            Divider().padding(.vertical, 4)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .system(size: 28, weight: .bold, design: .rounded)
        case 2: .system(size: 21, weight: .bold, design: .rounded)
        case 3: .system(size: 18, weight: .semibold, design: .rounded)
        default: .system(size: 16, weight: .semibold)
        }
    }
}

private struct InlineMarkdownText: View {
    let text: String

    var body: some View {
        Text(attributed)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributed: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

private struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]

    private var columnCount: Int {
        max(headers.count, rows.map(\.count).max() ?? 0)
    }

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(0..<columnCount, id: \.self) { column in
                        cell(headers[safe: column] ?? "", isHeader: true)
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(0..<columnCount, id: \.self) { column in
                            cell(row[safe: column] ?? "", isHeader: false)
                                .background(rowIndex.isMultiple(of: 2) ? .clear : .primary.opacity(0.025))
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.45))
            )
        }
    }

    private func cell(_ text: String, isHeader: Bool) -> some View {
        InlineMarkdownText(text: text)
            .font(.system(size: 14, weight: isHeader ? .semibold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(minWidth: 120, maxWidth: 280, alignment: .leading)
            .background(isHeader ? Color.primary.opacity(0.065) : Color.clear)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
