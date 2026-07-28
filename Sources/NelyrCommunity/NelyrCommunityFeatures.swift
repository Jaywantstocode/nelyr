import NelyrCore

/// The always-available, MIT-licensed feature set. Local enrichment and the
/// external research bridge remain open; Pro can replace them with richer
/// engines without weakening Community capture.
public struct NelyrCommunityFeatures: NelyrFeatureBundle {
    public let manifest = NelyrFeatureManifest(
        identifier: "app.nelyr.community",
        displayName: "Nelyr Community",
        edition: .community,
        capabilities: [
            .rawCapture,
            .globalShortcuts,
            .localTranscription,
            .dictationHistory,
            .localOCR,
            .obsidianInbox,
            .localKnowledgeEnrichment,
            .externalResearchBridge,
            .appAwareDictation
        ]
    )

    public init() {}
}
