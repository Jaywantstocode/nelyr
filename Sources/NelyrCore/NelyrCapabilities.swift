import Foundation

/// The commercial edition represented by a feature bundle.
public enum NelyrEdition: String, Codable, Equatable, Sendable {
    case community
    case pro
}

/// Stable capability identifiers shared by the open app and optional feature
/// bundles. A paid bundle declares capabilities here; the app never checks
/// scattered `PRO` compiler flags.
public enum NelyrCapability: String, CaseIterable, Codable, Hashable, Sendable {
    case rawCapture
    case globalShortcuts
    case localTranscription
    case dictationHistory
    case localOCR
    case obsidianInbox
    case localKnowledgeEnrichment
    case externalResearchBridge
    case appAwareDictation
    case advancedKnowledgeGraph
    case advancedOCRWorkflows
    case multipleVaults
    case managedModelInstaller
    case managedUpdates
}

/// A value-only description of an installed feature bundle. Keeping this type
/// free of UI and model-runtime dependencies makes NelyrCore safe to import
/// from Community, Pro, command-line, and test targets.
public struct NelyrFeatureManifest: Equatable, Sendable {
    public let identifier: String
    public let displayName: String
    public let edition: NelyrEdition
    public let capabilities: Set<NelyrCapability>

    public init(
        identifier: String,
        displayName: String,
        edition: NelyrEdition,
        capabilities: Set<NelyrCapability>
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.edition = edition
        self.capabilities = capabilities
    }

    public func supports(_ capability: NelyrCapability) -> Bool {
        capabilities.contains(capability)
    }
}

/// The narrow public contract implemented by Community and future private
/// bundles. Runtime services are injected by the host app so this interface
/// stays stable as model implementations evolve.
public protocol NelyrFeatureBundle: Sendable {
    var manifest: NelyrFeatureManifest { get }
}
