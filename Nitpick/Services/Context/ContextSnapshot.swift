import Foundation

/// One action-scoped capture of approved context. Payloads live only in
/// memory for the duration of the request; History records `usedSources`
/// flags, never the payloads themselves.
struct ContextSnapshot: Sendable {
    var appName: String?
    var appBundleID: String?
    var clipboardText: String?
    var clipboardTruncated: Bool
    var clipboardOmittedReason: String?
    var localTime: String?
    var screenPNG: Data?

    init(
        appName: String? = nil,
        appBundleID: String? = nil,
        clipboardText: String? = nil,
        clipboardTruncated: Bool = false,
        clipboardOmittedReason: String? = nil,
        localTime: String? = nil,
        screenPNG: Data? = nil
    ) {
        self.appName = appName
        self.appBundleID = appBundleID
        self.clipboardText = clipboardText
        self.clipboardTruncated = clipboardTruncated
        self.clipboardOmittedReason = clipboardOmittedReason
        self.localTime = localTime
        self.screenPNG = screenPNG
    }

    var usedSources: [ContextSource] {
        var sources: [ContextSource] = []
        if appName != nil { sources.append(.app) }
        if clipboardText != nil { sources.append(.clipboard) }
        if localTime != nil { sources.append(.time) }
        if screenPNG != nil { sources.append(.screen) }
        return sources
    }
}
