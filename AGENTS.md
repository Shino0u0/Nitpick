# Vortext agent instructions

Native macOS voice utility. Swift 6 language mode, strict concurrency, SwiftUI + AppKit, SwiftData. GPLv3, no accounts, no telemetry, no backend.

## Source of truth

- `docs/SPEC.md` is the approved MVP spec. Do not add scope beyond it without a governance decision.
- `docs/plans/` holds implementation plans.

## Build and test

- `xcodegen generate` creates `Vortext.xcodeproj` (generated, never committed, never edited by hand; edit `project.yml`).
- Build: `xcodebuild build -scheme Vortext -destination 'platform=macOS' -quiet`
- Tests: `xcodebuild test -scheme Vortext -destination 'platform=macOS' -only-testing:VortextTests -quiet` (UI tests need a GUI session; run them separately).

## Hard rules

- API keys live only in Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, no sync). Never in SwiftData, UserDefaults, logs, fixtures, or test code. `SecretValue` wraps keys and must never gain a content-revealing description.
- Clipboard payloads and screenshots are never persisted.
- Default Mode never touches the network.
- Untrusted context (clipboard, app, screen) is delimited separately from instructions in provider prompts.
- Provider response fixtures must be sanitized; live provider tests are opt-in only.
- One runtime dependency allowed: FluidAudio. Adding any other requires a documented blocker first.
- Follow the module boundaries in `docs/SPEC.md` section 12: feature views depend on service protocols, not concrete implementations; provider-specific response types stay inside their adapter directory.
- Never commit, push, or open a PR unless the maintainer explicitly asked.
