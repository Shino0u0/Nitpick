import Foundation
import SwiftData

enum ContextSource: String, Codable, Sendable, CaseIterable {
    case app
    case clipboard
    case time
    case screen
}

enum EntryStatus: String, Codable, Sendable {
    case succeeded
    case failed
    case cancelled
}

/// Non-secret failure buckets recorded in History. Never raw error text
/// that could echo request contents.
enum ErrorCategory: String, Codable, Sendable {
    case transcriptionFailed
    case providerInvalidKey
    case providerRateLimited
    case providerUnavailable
    case modelRemoved
    case accessibilityUnavailable
    case placeholderCorrupted
    case network
    case unknown
}

@Model
final class ModeRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconSystemName: String
    var instructions: String
    var order: Int
    var isEnabled: Bool
    var allowedActions: [NitpickAction]
    var providerOverride: ProviderID?
    var modelOverride: String?
    var targetBundleIDs: [String]
    /// True only for the permanent Default Mode: local-only, undeletable,
    /// uneditable, always listed first.
    var isSystemDefault: Bool

    init(
        id: UUID = UUID(),
        name: String,
        iconSystemName: String,
        instructions: String,
        order: Int = 0,
        isEnabled: Bool = true,
        allowedActions: [NitpickAction],
        providerOverride: ProviderID? = nil,
        modelOverride: String? = nil,
        targetBundleIDs: [String] = [],
        isSystemDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.instructions = instructions
        self.order = order
        self.isEnabled = isEnabled
        self.allowedActions = allowedActions
        self.providerOverride = providerOverride
        self.modelOverride = modelOverride
        self.targetBundleIDs = targetBundleIDs
        self.isSystemDefault = isSystemDefault
    }
}

@Model
final class HistoryEntry {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var duration: TimeInterval?
    var action: NitpickAction
    var status: EntryStatus
    var modeID: UUID?
    var modeName: String?
    var providerID: ProviderID?
    var modelID: String?
    var targetAppBundleID: String?
    var targetAppName: String?
    var originalTranscript: String
    var finalOutput: String?
    /// Which context source types were used; payloads are never persisted.
    var usedContext: [ContextSource]
    var audioFilePath: String?
    var errorCategory: ErrorCategory?

    var audioFileURL: URL? {
        audioFilePath.map { URL(filePath: $0) }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        duration: TimeInterval? = nil,
        action: NitpickAction,
        status: EntryStatus,
        modeID: UUID? = nil,
        modeName: String? = nil,
        providerID: ProviderID? = nil,
        modelID: String? = nil,
        targetAppBundleID: String? = nil,
        targetAppName: String? = nil,
        originalTranscript: String,
        finalOutput: String?,
        usedContext: [ContextSource] = [],
        audioFileURL: URL? = nil,
        errorCategory: ErrorCategory? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.duration = duration
        self.action = action
        self.status = status
        self.modeID = modeID
        self.modeName = modeName
        self.providerID = providerID
        self.modelID = modelID
        self.targetAppBundleID = targetAppBundleID
        self.targetAppName = targetAppName
        self.originalTranscript = originalTranscript
        self.finalOutput = finalOutput
        self.usedContext = usedContext
        self.audioFilePath = audioFileURL?.path
        self.errorCategory = errorCategory
    }
}

@Model
final class DictionaryEntryRecord {
    @Attribute(.unique) var id: UUID
    var phrase: String
    var replacement: String
    var isEnabled: Bool
    var isCaseSensitive: Bool
    var isProtectedLiteral: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        phrase: String,
        replacement: String,
        isEnabled: Bool = true,
        isCaseSensitive: Bool = false,
        isProtectedLiteral: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.phrase = phrase
        self.replacement = replacement
        self.isEnabled = isEnabled
        self.isCaseSensitive = isCaseSensitive
        self.isProtectedLiteral = isProtectedLiteral
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var asRule: DictionaryRule {
        DictionaryRule(
            phrase: phrase,
            replacement: replacement,
            isEnabled: isEnabled,
            isCaseSensitive: isCaseSensitive,
            isProtectedLiteral: isProtectedLiteral
        )
    }
}

/// Connection metadata only; the key itself lives exclusively in Keychain.
@Model
final class ProviderConfiguration {
    /// ProviderID raw value; stored as String because CoreData uniqueness
    /// constraints reject codable enum attributes.
    @Attribute(.unique) var providerRawValue: String
    var isConnected: Bool
    var selectedModelID: String?
    var lastModelRefresh: Date?

    var providerID: ProviderID? {
        get { ProviderID(rawValue: providerRawValue) }
        set { providerRawValue = newValue?.rawValue ?? providerRawValue }
    }

    init(
        providerID: ProviderID,
        isConnected: Bool = false,
        selectedModelID: String? = nil,
        lastModelRefresh: Date? = nil
    ) {
        self.providerRawValue = providerID.rawValue
        self.isConnected = isConnected
        self.selectedModelID = selectedModelID
        self.lastModelRefresh = lastModelRefresh
    }
}

@Model
final class AppSettings {
    var onboardingCompleted: Bool
    var contextConsentGranted: Bool
    var enabledContextSources: [ContextSource]
    var dictateShortcut: String?
    var askShortcut: String?
    var selectedInputDeviceUID: String?
    var defaultProviderID: ProviderID?
    var defaultModelID: String?

    init(
        onboardingCompleted: Bool = false,
        contextConsentGranted: Bool = false,
        enabledContextSources: [ContextSource] = ContextSource.allCases,
        dictateShortcut: String? = nil,
        askShortcut: String? = nil,
        selectedInputDeviceUID: String? = nil,
        defaultProviderID: ProviderID? = nil,
        defaultModelID: String? = nil
    ) {
        self.onboardingCompleted = onboardingCompleted
        self.contextConsentGranted = contextConsentGranted
        self.enabledContextSources = enabledContextSources
        self.dictateShortcut = dictateShortcut
        self.askShortcut = askShortcut
        self.selectedInputDeviceUID = selectedInputDeviceUID
        self.defaultProviderID = defaultProviderID
        self.defaultModelID = defaultModelID
    }
}
