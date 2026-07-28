import Foundation

enum LifeCaptureType: String, CaseIterable, Codable, Equatable, Sendable {
    case unclassified
    case idea
    case goal
    case reflection
    case memory
    case learning
    case question

    static var modelValues: [String] {
        allCases.filter { $0 != .unclassified }.map(\.rawValue)
    }
}

enum LifeArea: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case selfArea = "self"
    case relationships
    case health
    case work
    case finance
    case creativity
    case home
    case travel
    case community
}

struct IdeaEnrichment: Codable, Equatable, Sendable {
    let title: String
    let summary: String
    let significance: String
    let type: LifeCaptureType
    let areas: [LifeArea]
    let tags: [String]
    let nextStep: String

    var isValid: Bool {
        let uniqueAreas = Set(areas)
        return type != .unclassified
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !significance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (1...3).contains(areas.count)
            && uniqueAreas.count == areas.count
            && tags.count <= 5
    }

    enum CodingKeys: String, CodingKey {
        case title, summary, significance, type, areas, tags
        case nextStep = "next_step"
    }
}

enum CaptureKind: String, Equatable, Sendable {
    case text
    case screenshot
}

struct CapturedNote: Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let originalText: String
    let captureKind: CaptureKind
    let fileURL: URL
    let originalModificationDate: Date?
}

struct VaultNote: Equatable, Sendable {
    let fileURL: URL
    let title: String
    let linkName: String
    let searchableText: String
    let modifiedAt: Date
}

struct RelatedIdea: Equatable, Sendable {
    let linkName: String
    let title: String
    let score: Double
}

enum IdeaTemplateRenderer {
    static let defaultTemplate = """
    ---
    id: "{{id}}"
    created: {{created}}
    type: {{type}}
    areas:
    {{areas_yaml}}
    status: {{status}}
    summary: "{{summary_yaml}}"
    tags:
    {{tags_yaml}}
    related:
    {{related_yaml}}
    source: daily-desk
    capture_kind: {{capture_kind}}
    ai_model: {{ai_model}}
    ---

    # {{title}}

    ## Original thought

    {{original}}

    ## Essence

    {{summary}}

    ## Why it matters

    {{significance}}

    ## Connections

    {{connections}}

    ## Possible next step

    {{next_step}}

    ## Topics

    {{inline_tags}}
    """

    static let previousDefaultTemplate = defaultTemplate.replacingOccurrences(
        of: "capture_kind: {{capture_kind}}\n",
        with: ""
    )

    static let legacyDefaultTemplate = """
    ---
    id: "{{id}}"
    created: {{created}}
    type: idea
    status: {{status}}
    summary: "{{summary_yaml}}"
    tags:
    {{tags_yaml}}
    related:
    {{related_yaml}}
    source: daily-desk
    ai_model: {{ai_model}}
    ---

    # {{title}}

    ## Original thought

    {{original}}

    ## Summary

    {{summary}}

    ## Connections

    {{connections}}

    ## Next step

    {{next_step}}

    ## Topics

    {{inline_tags}}
    """

    static let requiredPlaceholders = [
        "{{id}}", "{{created}}", "{{status}}", "{{title}}",
        "{{original}}", "{{summary}}", "{{tags_yaml}}"
    ]

    static func isValidTemplate(_ template: String) -> Bool {
        requiredPlaceholders.allSatisfy(template.contains)
    }

    static func renderRaw(
        id: UUID,
        createdAt: Date,
        original: String,
        captureKind: CaptureKind = .text,
        template: String = defaultTemplate
    ) -> String {
        render(
            id: id,
            createdAt: createdAt,
            original: original,
            captureKind: captureKind,
            enrichment: IdeaEnrichment(
                title: "Unprocessed capture",
                summary: "Awaiting local AI enrichment.",
                significance: "Awaiting local AI enrichment.",
                type: .unclassified,
                areas: [],
                tags: ["needs-enrichment"],
                nextStep: ""
            ),
            related: [],
            status: "needs-enrichment",
            model: "pending",
            template: template
        )
    }

    static func render(
        id: UUID,
        createdAt: Date,
        original: String,
        captureKind: CaptureKind = .text,
        enrichment: IdeaEnrichment,
        related: [RelatedIdea],
        status: String = "inbox",
        model: String,
        template: String = defaultTemplate
    ) -> String {
        let safeTemplate = isValidTemplate(template) ? template : defaultTemplate
        let normalizedTags = TagNormalizer.tags(for: enrichment)
        let tagsYAML = normalizedTags.map { "  - \($0)" }.joined(separator: "\n")
        let areasYAML = enrichment.areas.isEmpty
            ? "  []"
            : enrichment.areas.map { "  - \($0.rawValue)" }.joined(separator: "\n")
        let relatedYAML = related.isEmpty
            ? "  []"
            : related.map { "  - \"[[\(escapeYAML($0.linkName))]]\"" }.joined(separator: "\n")
        let connections = related.isEmpty
            ? "No related notes yet."
            : related.map { "- [[\($0.linkName)]] — related by meaning" }.joined(separator: "\n")
        let nextStep = enrichment.nextStep.trimmingCharacters(in: .whitespacesAndNewlines)
        let inlineTags = normalizedTags.map { "#\($0)" }.joined(separator: " ")

        let values: [String: String] = [
            "{{id}}": id.uuidString.lowercased(),
            "{{created}}": ISO8601DateFormatter().string(from: createdAt),
            "{{capture_kind}}": captureKind.rawValue,
            "{{type}}": enrichment.type.rawValue,
            "{{areas_yaml}}": areasYAML,
            "{{status}}": status,
            "{{summary_yaml}}": escapeYAML(enrichment.summary),
            "{{tags_yaml}}": tagsYAML,
            "{{related_yaml}}": relatedYAML,
            "{{ai_model}}": model,
            "{{title}}": sanitizeHeading(enrichment.title),
            "{{original}}": original.trimmingCharacters(in: .whitespacesAndNewlines),
            "{{summary}}": enrichment.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            "{{significance}}": enrichment.significance.trimmingCharacters(in: .whitespacesAndNewlines),
            "{{connections}}": connections,
            "{{next_step}}": nextStep.isEmpty ? "No action needed." : "- [ ] \(nextStep)",
            "{{inline_tags}}": inlineTags
        ]

        return values.reduce(safeTemplate) { partial, entry in
            partial.replacingOccurrences(of: entry.key, with: entry.value)
        } + "\n"
    }

    static func safeFilename(for title: String, createdAt: Date, id: UUID) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = title
            .components(separatedBy: forbidden)
            .joined(separator: "-")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        let base = String((cleaned.isEmpty ? "Capture" : cleaned).prefix(80))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "\(base) - \(formatter.string(from: createdAt))-\(id.uuidString.prefix(6).lowercased()).md"
    }

    private static func escapeYAML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func sanitizeHeading(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TagNormalizer {
    static func normalize(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.compactMap { raw in
            var tag = raw.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                .replacingOccurrences(of: "_", with: "-")
                .replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
                .replacingOccurrences(of: #"[^a-z0-9/\-]"#, with: "", options: .regularExpression)
            tag = tag.replacingOccurrences(of: #"-+"#, with: "-", options: .regularExpression)
            guard !tag.isEmpty, seen.insert(tag).inserted else { return nil }
            return tag
        }
    }

    static func tags(for enrichment: IdeaEnrichment) -> [String] {
        normalize(
            ["type/\(enrichment.type.rawValue)"]
                + enrichment.areas.map { "area/\($0.rawValue)" }
                + enrichment.tags
        )
    }
}

enum VectorMath {
    static func cosineSimilarity(_ lhs: [Float], _ rhs: [Float]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        var dot: Double = 0
        var lhsMagnitude: Double = 0
        var rhsMagnitude: Double = 0
        for index in lhs.indices {
            let left = Double(lhs[index])
            let right = Double(rhs[index])
            dot += left * right
            lhsMagnitude += left * left
            rhsMagnitude += right * right
        }
        guard lhsMagnitude > 0, rhsMagnitude > 0 else { return 0 }
        return dot / (sqrt(lhsMagnitude) * sqrt(rhsMagnitude))
    }
}
