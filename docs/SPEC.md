# Vortext MVP Product and Technical Specification

**Status:** Final — approved for implementation planning  
**Version:** 1.0  
**Date:** August 16, 2026  
**Product:** Vortext for macOS  
**License:** GNU General Public License v3.0

## 1. Product Summary

Vortext is a small, native macOS voice utility. It records speech, transcribes it locally, optionally improves or answers it with a user-selected cloud model, and either inserts the result into the active application or displays it in Vortext.

The MVP is deliberately smaller than VoiceInk. It has no license gate, account system, subscription, analytics, marketplace, or large provider abstraction framework. Its default path remains useful offline after the local transcription model has been downloaded.

### 1.1 Product promise

- Fast voice-to-text anywhere on macOS.
- A permanent local-only transcription mode.
- Optional cloud-assisted Modes for rewriting and answering.
- Bring-your-own-key access to multiple model providers.
- Transparent, action-scoped clipboard, app, time, and screen context.
- Local history, dictionary, settings, and credentials.
- A quiet interface that stays out of the way.

### 1.2 MVP goals

1. Provide reliable local transcription with one bundled model integration.
2. Insert dictated text into the frontmost application.
3. Support Groq, OpenRouter, SambaNova, and Cerebras through direct HTTPS APIs.
4. Fetch each provider's available models dynamically after an API key is validated.
5. Provide Dictate and Ask actions.
6. Provide a permanent Default Mode and customizable AI Modes.
7. Apply deterministic dictionary replacements before cloud enhancement.
8. Record editable original and final text in local History with audio playback.
9. Include approved context without continuously monitoring the user.
10. Keep API keys in macOS Keychain and nowhere else.

### 1.3 Non-goals for MVP

- User accounts, login, subscriptions, trials, or license activation.
- A Vortext backend or proxy server.
- Syncing settings, history, audio, or API keys between Macs.
- Multiple local transcription engines or model pickers.
- Local LLM enhancement.
- Mobile, Windows, or web clients.
- Plugin systems, teams, prompt marketplaces, or shared Modes.
- Automatic actions that send messages, emails, or submit forms.
- Continuous clipboard, screen, application, or microphone monitoring.
- Automatic software updates in the first build.

## 2. Supported Platform and Stack

### 2.1 Platform

- macOS 15.0 or later.
- Apple silicon is the primary target for the MVP.
- Swift 6.2 with strict concurrency enabled.
- Xcode 26.1 or later for development.

### 2.2 Apple frameworks

- SwiftUI for the main application and onboarding.
- AppKit for menu-bar, floating-panel, focus, and window behavior.
- AVFoundation/CoreAudio for microphone capture.
- SwiftData for local application records.
- Security framework for Keychain operations.
- ApplicationServices Accessibility APIs for inserting text.
- ScreenCaptureKit for explicit, action-scoped screen context.
- `NSWorkspace` for the frontmost application.
- `NSPasteboard` for an action-scoped clipboard snapshot.
- `URLSession` for all provider networking.

### 2.3 Third-party dependencies

The MVP should have one direct runtime package dependency:

- FluidAudio for local Parakeet transcription.

Provider integrations use `URLSession` directly. Do not add LLMkit or another provider SDK during the MVP unless an implementation blocker is documented first. Do not add Sparkle, MarkdownUI, Zip, SelectedTextKit, or MLX packages initially.

All dependency versions must be pinned in `Package.resolved`.

## 3. Experience Model

Vortext has two primary surfaces:

1. A compact floating recorder pill.
2. A main window with four tabs.

### 3.1 Dictate

1. The user invokes the Dictate shortcut or recorder control.
2. Vortext remembers the target application and starts recording.
3. The user stops recording.
4. Vortext transcribes locally.
5. The dictionary transforms recognized phrases.
6. If Default Mode is selected, Vortext inserts the transcript immediately.
7. If a custom Mode is selected, Vortext assembles approved context, requests cloud enhancement, and inserts the result.
8. Vortext stores the local History entry.

### 3.2 Ask

1. The user invokes the Ask shortcut or switches the pill to Ask.
2. Vortext records and transcribes locally.
3. The dictionary transforms recognized phrases.
4. Vortext sends the selected custom Mode, transcript, and approved context to the selected cloud model.
5. The response appears in a compact Vortext response panel.
6. The user may edit or copy the answer.
7. Vortext stores the local History entry.

Ask requires a configured cloud model. When no cloud model is available, Vortext explains what is missing and preserves the transcript.

### 3.3 Default Mode

- Named `Default`.
- Permanently present and always listed first.
- Cannot be renamed, edited, reordered, or deleted.
- Performs transcription and dictionary replacement only.
- Never invokes a cloud provider.
- Never sends clipboard, application, time, or screen context anywhere.
- Remains functional offline after the local model is installed.

## 4. Visual Design Contract: Quiet Utility

The interface must follow the selected Quiet Utility direction. It should feel calm, editorial, compact, and native to macOS. It must not reproduce VoiceInk's current purchase, trial, dashboard, or promotional interface.

### 4.1 Foundation

- Main canvas: warm off-white `#F7F5EF`.
- Secondary canvas: warm gray `#E9E7E0`.
- Navigation rail and primary dark controls: charcoal `#202624`.
- Primary text: near-black `#1C211F`.
- Accent: restrained lime `#C8FF4D`.
- Success tint: `#DFF8B2`.
- Borders: approximately 13% to 16% charcoal opacity.
- Cards: white or near-white with thin borders, not heavy shadows.
- Corner radii: 8–13 points for functional surfaces; recorder pill uses a capsule.

System semantic colors must replace fixed colors where required for legibility, increased contrast, or accessibility. Dark Mode should preserve the quiet hierarchy rather than invert every color literally.

### 4.2 Typography and density

- Use the system typeface.
- Compact editorial hierarchy with short headings and plain explanations.
- Small uppercase eyebrow labels may identify setup sections.
- Avoid oversized marketing headlines.
- Avoid gradients, glass effects, glowing orbs, decorative animation, and dense dashboards.
- Controls must meet macOS accessibility sizing even when the surrounding layout is compact.

### 4.3 Main window navigation

The tabs appear in this exact order:

1. History
2. Models
3. Modes
4. Dictionary

Use a compact dark navigation rail on the left. History is the default landing tab after onboarding.

### 4.4 Floating recorder pill

The global recorder is not a fifth tab. It is a small floating panel containing:

- Stop/record control.
- Live waveform.
- Dictate or Ask indicator.
- Selected Mode icon.
- Compact context indicators for App, Clipboard, Time, and Screen.
- Processing or provider status when needed.

The panel must remain operable with VoiceOver and keyboard navigation. Animation must respect Reduce Motion.

## 5. Onboarding

Onboarding uses a compact left progress rail and one focused task per page. Each permission is explained before macOS displays its system prompt.

### 5.1 Sequence

1. **Welcome:** Explain local transcription, optional cloud enhancement, and no account requirement.
2. **Access:** Explain all permission categories and which are optional.
3. **Microphone:** Request microphone access and allow input-device selection.
4. **Local Model:** Download and verify the single Parakeet model with visible progress and retry.
5. **Accessibility:** Explain text insertion, request trust, and verify the result.
6. **Screen Context:** Explain what is captured and transmitted; allow Skip.
7. **Models:** Connect one optional cloud provider, validate the key, fetch models, and choose a default model. Allow Skip.
8. **Shortcuts:** Configure Dictate and Ask shortcuts and reject conflicts.
9. **Try Dictate:** Record a safe local sample.
10. **Try Ask:** Run only when a cloud provider is configured; otherwise explain how to enable it later.
11. **Complete:** Open History and keep Vortext in the menu bar.

### 5.2 Permission fallback behavior

- Microphone denied: browsing settings remains available, but recording is disabled with a direct route to System Settings.
- Accessibility denied: Dictate places the result on the clipboard and clearly reports `Copied—paste into your app`.
- Screen Recording denied: all voice and text features continue without screen context.
- Cloud context consent denied or revoked: Default continues normally; custom Modes send only the spoken transcript until consent is granted.

## 6. Main Tabs

### 6.1 History

Each History row displays:

- Timestamp and duration.
- Dictate or Ask.
- Mode name and icon.
- Target application name when available.
- Original transcript.
- Final output.
- Context types used, without saving the context payloads.
- Success, failure, or cancelled status.

Opening an entry provides:

- Editable original and final text fields.
- Independent copy controls for original and final text.
- Local audio playback with play/pause, scrubber, elapsed time, and duration.
- Retry enhancement when the original transcript and Mode still exist.
- Delete entry.

Audio is stored locally until its History entry is deleted or History is cleared. Deleting an entry must also delete its audio file. Screenshots and clipboard contents are never retained in History.

### 6.2 Models

The top of Models contains a horizontally scrolling provider strip:

`Groq` · `OpenRouter` · `SambaNova` · `Cerebras`

Requirements:

- Provider items are capsule-shaped pills.
- Mouse wheel, trackpad horizontal scroll, Shift-scroll, and keyboard navigation work.
- Edge fades or a thin native scroll indicator communicate additional content.
- Selecting a provider opens its configuration card.
- Configuration contains a secure key field, Test Connection, Replace Key, Remove Key, refresh status, fetched model dropdown, and provider dashboard link.
- The full stored key is never redisplayed.
- A provider key is saved only after a successful explicit connection test.
- A failed test leaves any previously working stored key unchanged.
- Models are loaded from cache immediately and refreshed when stale or manually requested.

Each normalized model may display:

- Provider model identifier.
- Display name when supplied.
- Context-window size when supplied.
- Text and image-input capability when known.
- Availability state.

Unknown capability must be treated conservatively as text-only. Vortext must never attach a screenshot merely because a model name appears to imply vision.

### 6.3 Modes

Modes are user-facing AI behaviors. `Enhancement` is an internal pipeline term, not the navigation label.

The Default Mode is pinned first. Custom Modes support:

- Name.
- SF Symbol or Vortext-composed system icon.
- Instruction text.
- Optional provider/model override; otherwise use the global default cloud model.
- Optional target application rules using bundle identifiers.
- Dictate, Ask, or both as allowed destinations.
- Create, duplicate, reorder, edit, enable/disable, and delete.

Initial optional examples may include Email, Reply, Rewrite, Notes, and Casual. These are editable examples, not permanent system Modes.

Custom artwork copied from VoiceInk must not be used. Icons should use SF Symbols and simple shapes produced inside Vortext.

### 6.4 Dictionary

Dictionary entries contain:

- Spoken phrase.
- Replacement value.
- Enabled state.
- Case-sensitive matching option, off by default.

Examples:

- `my email` → `myemail@personemail.com`
- `nit pick` → `Vortext`

The Dictionary includes create, edit, delete, search, enable/disable, and a small test field that previews replacements without invoking AI.

## 7. Dictionary Algorithm

Dictionary replacement is deterministic and local.

### 7.1 Matching

1. Normalize matching text with Unicode compatibility normalization.
2. Collapse repeated whitespace for matching while retaining original punctuation boundaries.
3. Tokenize entries and transcripts into locale-aware word tokens.
4. Store enabled phrases in a token trie.
5. Scan from left to right.
6. At each token, choose the longest complete phrase match.
7. Replace only whole words or whole multi-word phrases.
8. Preserve punctuation outside the matched span.
9. Never use fuzzy, phonetic, substring, or edit-distance matching in the MVP.

This makes `my email address` win over `my email` when both exist and prevents an entry such as `art` from changing `partial`.

### 7.2 Protected replacements

After dictionary replacement and before cloud enhancement:

1. Protect dictionary values that look like email addresses, URLs, identifiers, handles, or user-marked literals with unique placeholders.
2. Send the placeholders and a clear non-editable-value instruction to the model.
3. Restore the exact local values after the model responds.
4. Reject or safely recover malformed placeholder output.

The LLM may improve surrounding text but must not alter protected replacement values.

## 8. Context System

Context is captured only as part of an explicit Dictate or Ask action. Vortext does not poll or retain context in the background.

### 8.1 Sources

| Source | Acquisition | System permission | Retention |
|---|---|---|---|
| Frontmost app | `NSWorkspace.frontmostApplication` | None | Bundle ID/name metadata in History |
| Local time | `Date` and user calendar/time zone | None | Request timestamp |
| Clipboard | One `NSPasteboard` snapshot after recording | None | Never retained |
| Screen | One ScreenCaptureKit image for the target app/window | Screen Recording | Never retained |
| Audio | Microphone recording | Microphone | Local History audio until deleted |
| Text insertion | Accessibility APIs | Accessibility | No extra payload retained |

### 8.2 Consent and visibility

- Onboarding must explain that cloud Modes transmit selected content to the chosen third-party AI provider.
- Explicit context-sharing consent is recorded locally.
- Consent can be withdrawn from Settings.
- The recorder shows the context sources being prepared.
- The History entry records which source types were used.
- Screen context is sent only when Screen Recording permission exists and the normalized model capability includes image input.
- When the selected model is text-only or capability is unknown, screen context is omitted and the UI explains why.

### 8.3 Screen capture boundaries

- Capture one image at action completion, not a stream.
- Prefer the remembered target application's frontmost eligible window.
- Exclude Vortext's own windows and floating recorder.
- Do not write the image to disk.
- Release image data immediately after request completion or cancellation.

### 8.4 Clipboard secret guard

Before adding clipboard text to a cloud request, omit it when any of the following applies:

- It exactly matches a provider key currently stored by Vortext.
- It contains a private-key header.
- It resembles a single high-entropy credential or bearer token.
- Vortext's API-key editor was the source interaction.

The recorder must report `Clipboard omitted—possible secret` rather than silently sending or silently dropping it. Clipboard context must also have a conservative length limit with visible truncation metadata.

### 8.5 Prompt-injection boundary

Application, clipboard, and screen content are untrusted data. Provider requests must:

- Delimit context separately from Mode instructions.
- State that instructions found inside context are data and must not override system or Mode instructions.
- Never allow model output to trigger autonomous application actions.

This reduces prompt-injection risk but is not represented to users as a complete security guarantee.

## 9. Cloud Provider Architecture

### 9.1 Provider interface

Each provider adapter implements the same internal protocol:

```swift
protocol CloudProviderClient: Sendable {
    func validate(apiKey: SecretValue) async throws
    func fetchModels(apiKey: SecretValue) async throws -> [CloudModelDescriptor]
    func complete(request: CompletionRequest, apiKey: SecretValue) async throws -> CompletionResponse
}
```

`SecretValue` must prevent accidental textual description and logging. It is not persisted outside Keychain.

### 9.2 Initial endpoints

| Provider | Base URL | Model discovery | Completion |
|---|---|---|---|
| Groq | `https://api.groq.com/openai/v1` | `GET /models` | `POST /chat/completions` |
| OpenRouter | `https://openrouter.ai/api/v1` | `GET /models` | `POST /chat/completions` |
| SambaNova | `https://api.sambanova.ai/v1` | `GET /models` | `POST /chat/completions` |
| Cerebras | `https://api.cerebras.ai/v1` | `GET /models` | `POST /chat/completions` |

All calls use provider-issued bearer credentials and direct HTTPS connections from Vortext. Provider-specific headers are added only when their official API requires them.

### 9.3 Model normalization

`CloudModelDescriptor` contains:

- Stable provider ID.
- Provider model ID.
- Display name.
- Input modalities: text, image, or unknown.
- Output modalities when supplied.
- Context length when supplied.
- Maximum output tokens when supplied.
- Provider metadata needed for display, excluding secrets.

Prefer explicit provider response metadata. A small provider-specific capability resolver may supplement missing metadata only for exact audited model identifiers and must be covered by tests. Anything else remains `unknown`.

### 9.4 Cache and refresh

- Persist successful model-list responses without authorization headers or keys.
- Show cached models immediately on launch.
- Treat cache older than 24 hours as stale and refresh in the background when that provider is opened.
- Provide a manual Refresh action.
- Keep stale models visible during transient network failures, clearly marked with the last refresh time.
- If a selected model disappears, do not silently switch models; require a new selection.

## 10. Credential Security

### 10.1 Keychain storage

Store each provider key as a separate `kSecClassGenericPassword` item using:

- Service: stable Vortext-specific service identifier.
- Account: stable provider identifier.
- Accessibility: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Synchronization: disabled.
- No shared Keychain access group.

Use a stable bundle identifier and signing identity across builds. Check every `SecItemAdd`, `SecItemUpdate`, `SecItemCopyMatching`, and `SecItemDelete` status and map failures to actionable errors without exposing secret data.

### 10.2 Runtime handling

- Retrieve a key only for validation, model discovery, or completion.
- Do not maintain a process-lifetime key cache.
- Never conform secret wrappers to `CustomStringConvertible` with their contents.
- Redact `Authorization`, provider-key fields, and request headers from all diagnostics.
- Do not include keys in SwiftUI restoration, previews, fixtures, screenshots, or crash metadata.
- Replacing a key validates the replacement before overwriting the working Keychain item.
- Removing a provider deletes its local Keychain item and model cache.

### 10.3 Transport

- Use `URLSession` and default App Transport Security.
- Permit only HTTPS provider endpoints.
- Add no `NSAllowsArbitraryLoads` exception.
- Use default platform certificate validation without bypasses.
- Apply request timeouts and cancellation.
- Do not automatically retry authentication failures.

### 10.4 Security boundary

Keychain protects credentials at rest on an uncompromised Mac. Vortext must not claim protection from administrator-level malware, keyloggers, provider compromise, or live process-memory inspection.

## 11. Local Persistence

SwiftData stores non-secret application state.

### 11.1 Records

**ProviderConfiguration**

- Provider ID.
- Connection status.
- Selected default model ID.
- Last model refresh date.
- No API-key value.

**ModeRecord**

- ID, name, icon, instructions, order, enabled state.
- Allowed destination.
- Optional provider and model override.
- Optional target bundle identifiers.
- System flag for immutable Default Mode.

**DictionaryEntry**

- ID, phrase, replacement, enabled state, case-sensitivity flag, timestamps.

**HistoryEntry**

- ID, timestamps, duration, action, status.
- Mode/provider/model identifiers when applicable.
- Target application metadata.
- Original transcript and final output.
- Used-context flags only.
- Local audio-file reference.
- Non-secret error category when failed.

**AppSettings**

- Onboarding completion.
- Context-sharing consent and source preferences.
- Shortcut definitions.
- Selected input device.
- Global default cloud provider and model.
- Appearance and retention preferences added later.

### 11.2 Local storage rules

- No CloudKit or iCloud synchronization in the MVP.
- No provider API key in SwiftData.
- No clipboard payload or screenshot in SwiftData.
- Clearing History deletes associated audio files.
- Uninstall behavior follows normal macOS application-container behavior; Vortext must also provide explicit Clear History and Remove Provider actions.

## 12. Module Boundaries

```text
Vortext/
├── App/
├── Core/
│   ├── Models/
│   ├── Persistence/
│   └── DesignSystem/
├── Services/
│   ├── Audio/
│   ├── Transcription/
│   ├── Accessibility/
│   ├── Context/
│   ├── Dictionary/
│   ├── Keychain/
│   └── Providers/
├── Features/
│   ├── Onboarding/
│   ├── Recorder/
│   ├── History/
│   ├── Models/
│   ├── Modes/
│   └── Dictionary/
└── Resources/
```

Feature views depend on service protocols, not concrete provider or system implementations. Provider-specific response structures stay inside their adapter directories.

## 13. Processing Pipeline

```text
Shortcut
  → remember target app
  → record audio
  → local transcription
  → dictionary longest-match replacement
  → protect literal replacements
  → resolve Default or custom Mode
      → Default: restore literals → insert/copy
      → Custom: capture approved context
               → secret guard and context limits
               → provider request
               → restore protected literals
               → insert or show Ask panel
  → save History and local audio
```

The pipeline must be cancellable. A failure after transcription preserves the original transcript and audio so the user can copy, retry, or use Default Mode.

## 14. Error Handling

Errors should state the failed operation and the next useful action.

- Local model unavailable: resume or retry download.
- Microphone unavailable: choose another device or open permission settings.
- Accessibility unavailable: copy result for manual paste.
- Screen permission unavailable: continue without screen context.
- Keychain failure: identify save/read/delete operation and OS status without showing the secret.
- Invalid API key: preserve any previously validated key.
- Provider rate limit: preserve transcript and allow retry or provider switch.
- Provider timeout/offline: preserve transcript and offer Default output.
- Model removed: require explicit reselection.
- Unsafe clipboard candidate: omit and show the reason.
- Placeholder corruption: restore from local protected-value map or return the safe pre-enhancement transcript.

## 15. Accessibility and Quality

- Full keyboard navigation for onboarding, tabs, provider strip, editor controls, and recorder.
- VoiceOver labels and state announcements.
- Sufficient contrast in light and dark appearance.
- Reduce Motion support.
- Dynamic system text sizing where macOS supports it without breaking compact layouts.
- No color-only error or permission communication.
- Recorder controls remain reachable when the target app is full screen.

## 16. Acceptance Criteria

The MVP is complete when all of the following are demonstrably true:

1. A fresh user can complete or skip optional onboarding steps without a license screen.
2. Vortext downloads and uses one Parakeet local model.
3. Default Mode transcribes and inserts text without a network connection.
4. Accessibility denial produces a usable copy-and-paste fallback.
5. The main tabs are exactly History, Models, Modes, Dictionary.
6. Each initial provider can validate a key and dynamically fetch its models.
7. A full API key never appears in SwiftData, UserDefaults, application logs, History, or the UI after saving.
8. Provider keys use device-only, unlocked-only Keychain storage.
9. Custom Modes can enhance Dictate output and produce Ask responses.
10. The recorder visibly identifies context used by a cloud request.
11. Screen context is never sent to a text-only or unknown-capability model.
12. Clipboard context is omitted when it appears to contain a credential.
13. Dictionary replacement supports whole-word and longest multi-word matching.
14. Protected email addresses and URLs survive enhancement unchanged.
15. History shows editable original and final text with independent copy controls.
16. History audio can play, pause, scrub, and be deleted with its entry.
17. Screenshots and clipboard payloads are absent from persisted History.
18. Cloud failure preserves the local transcript and offers a safe recovery path.
19. The UI follows the Quiet Utility visual contract in onboarding and the main window.
20. Unit, integration, and UI tests pass under the supported Xcode version.
21. Source and downloadable binaries are publicly available without payment or activation.
22. The repository includes the community-health and governance files defined in Section 19.
23. Sponsors receive no gated features, priority access, or additional voting power.
24. Feature proposals can move transparently from Discussion to Poll to Issue to pull request.
25. Security, privacy, and licensing exceptions to a community vote receive a public maintainer explanation.
26. The project makes no claim that sponsorship is tax-deductible or that Claude program acceptance is guaranteed.

## 17. Required Test Coverage

### 17.1 Unit tests

- Dictionary Unicode normalization, token boundaries, overlaps, and longest match.
- Protected-value placeholder creation and restoration.
- Clipboard secret detection and truncation.
- Provider response decoding and normalization using sanitized fixtures.
- Vision-capability resolution and unknown fallback.
- Keychain query construction and OSStatus error mapping through an injectable wrapper.
- Prompt assembly keeps instructions separate from untrusted context.

### 17.2 Integration tests

- Audio fixture to local transcription pipeline.
- Default pipeline with no network client.
- Custom Mode pipeline using stub provider and context collectors.
- SwiftData History creation and cascade audio deletion.
- Provider model cache stale/fresh behavior.
- Failed replacement key validation preserves the previous credential.

### 17.3 UI tests

- Complete onboarding with optional steps skipped.
- Provider strip keyboard and horizontal-scroll behavior.
- Create/edit/delete custom Mode while Default remains immutable.
- Create and test a multi-word Dictionary entry.
- Edit/copy original and final History values.
- Permission-denied states remain navigable and understandable.

Live provider tests must be opt-in and read keys from the developer's Keychain or CI secret store. Real keys must never be committed or included in test fixtures.

## 18. Distribution and Licensing

- The repository and distributed source are GPLv3.
- Official Vortext binaries are free of charge and contain no activation or license-key check.
- Include the complete GPLv3 `LICENSE` file at repository root.
- Preserve required notices for any GPL-covered source that is actually reused.
- A clean implementation inspired by behavior must not copy VoiceInk trademarks, icons, screenshots, proprietary service configuration, or non-code assets.
- Use a stable Vortext bundle identifier and Developer ID signing identity before external distribution.
- Distribution decisions between direct notarized download and the Mac App Store occur after Accessibility, sandbox, and update requirements are validated.
- Direct, notarized GitHub Releases are the preferred first public distribution path.
- The GPLv3 software license and voluntary project funding are separate. Vortext must not call sponsorship a software license.

## 19. Open-Source Governance and Sustainability

Vortext is a public, community-guided GPLv3 project. Users may use, inspect, modify, build, and redistribute it under the GPLv3 terms. The official repository remains maintainer-reviewed so community choice does not bypass security, privacy, testing, or licensing requirements.

### 19.1 Funding model

- Funding is voluntary and never required to download, build, use, modify, or contribute to Vortext.
- The preferred label is `Support Vortext` or `Sponsor development`, not `Buy a license`.
- Configure GitHub Sponsors through `.github/FUNDING.yml`.
- Support one-time and recurring sponsorship when the selected funding platform permits it.
- Sponsor benefits may include public acknowledgment and development updates only.
- Sponsors receive no gated features, earlier builds, weighted votes, privileged issue priority, or private source access.
- Do not describe sponsorship as a tax-deductible charitable donation unless Vortext later operates through an eligible tax-exempt entity and receives appropriate professional guidance.
- The MVP contains no payment processing. The repository may display its GitHub Sponsor button. Vortext's About window may link to the public repository rather than embedding a checkout flow.
- Paid consulting, integration help, or support may be offered separately later without changing the GPL rights attached to Vortext.

### 19.2 Repository community files

The public repository must include:

- `README.md`: purpose, screenshots, privacy summary, install/build instructions, and contribution entry points.
- `LICENSE`: complete GPLv3 text.
- `CONTRIBUTING.md`: development setup, issue flow, tests, review requirements, and contributor expectations.
- `GOVERNANCE.md`: proposal, voting, maintainer, and decision rules.
- `CODE_OF_CONDUCT.md`: expected community behavior and enforcement contact.
- `SECURITY.md`: private vulnerability-reporting path and supported versions.
- `ROADMAP.md`: accepted priorities and their current status.
- `CODEOWNERS`: review ownership for security-sensitive and architectural areas.
- `.github/FUNDING.yml`: voluntary sponsorship configuration.
- `.github/ISSUE_TEMPLATE/`: structured bug and accepted-feature forms.
- `.github/PULL_REQUEST_TEMPLATE.md`: rationale, linked issue, tests, screenshots, privacy impact, and checklist.

### 19.3 Proposal and voting workflow

1. Anyone may propose a feature in the GitHub Discussions `Ideas` category.
2. Maintainers check for duplicates, sufficient problem definition, MVP fit, privacy impact, and feasibility.
3. A mature proposal moves to a GitHub Poll for at least seven calendar days.
4. Each authenticated community member has one equal vote. Sponsorship does not affect voting.
5. A simple majority guides acceptance and roadmap priority. Maintainers may extend an inconclusive or low-participation poll rather than manufacture a decision.
6. An accepted proposal becomes a scoped GitHub Issue with acceptance criteria.
7. Any contributor may implement the Issue through a pull request.
8. Required automated checks and human review must pass before merge.
9. The merged change appears in the Roadmap and release notes.

Votes govern product preference, not repository credentials. Maintainers retain final merge responsibility and may decline or defer a voted proposal only for documented security, privacy, legal, licensing, accessibility, architectural-maintainability, or project-scope reasons. The explanation must be posted publicly in the associated Discussion.

### 19.4 Contribution and release safeguards

- Protect the default branch and require pull requests.
- Require passing tests and at least one qualified review for normal changes.
- Require designated-owner review for Keychain, permissions, provider transmission, screen capture, update, signing, and release changes.
- Never ask contributors to place live API keys in issues, recordings, logs, fixtures, or pull requests.
- Use sanitized fixtures for provider parsing tests.
- Publish reproducible build instructions and attach source corresponding to every official binary release.
- Maintainers may cut emergency security releases without a prior community poll, followed by a public explanation after disclosure is safe.

## 20. Claude for Open Source Application Strategy

The maintainer intends to apply to Anthropic's Claude for Open Source Program. This is a sustainability goal, not a Vortext feature, entitlement, funding source, or reason to distort community metrics.

### 20.1 Current program facts

As of August 16, 2026, the program advertises six complimentary months of Claude Max 20x for qualifying open-source contributors. Anthropic lists several qualifying paths:

- Maintain packages with at least 500 dependent repositories, 100 dependent packages, or 200,000 combined monthly registry downloads.
- Be a listed core contributor or maintainer for a recognized foundation or language project.
- Author at least 100 pull requests merged into repositories the applicant does not own during the previous 12 months.
- Maintain a repository with at least 20 unique external contributors whose pull requests were merged during the previous 12 months.
- Maintain a repository with an OpenSSF criticality score of at least 0.4.
- Anthropic also invites maintainers of quieter ecosystem dependencies to apply and explain their impact even when a numeric threshold is not met.

Eligibility and program terms may change. The application must use the then-current official page and make only verifiable claims.

### 20.2 Vortext strategy

- Apply immediately only if the maintainer's existing open-source record supports an honest application.
- Otherwise, release Vortext publicly and build real usage and contribution history before reapplying.
- Optimize for healthy external contribution, not artificial contributor counts or low-quality pull requests.
- Track merged external contributors, releases, downstream usage, package downloads if applicable, security posture, and community outcomes as factual application evidence.
- Keep accepted proposals, polls, Issues, pull requests, and release notes public so impact is auditable.
- A paid activation gate is not part of this strategy and does not improve open-source eligibility.

The Claude Max benefit applies to the accepted contributor's Claude subscription. It is not Anthropic API credit for Vortext or its users. Vortext users still provide their own provider API keys.

At the end of the complimentary period, an existing paid Claude subscription may resume under Anthropic's current terms unless cancelled; an otherwise free account returns to the free plan. Vortext must not promise acceptance, renewal, API credits, or ongoing Anthropic sponsorship.

## 21. Official References

- Apple Keychain Services: https://developer.apple.com/documentation/security/keychain-services
- Apple Keychain accessibility: https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly
- Apple App Transport Security: https://developer.apple.com/documentation/security/preventing-insecure-network-connections
- Apple App Review privacy rules: https://developer.apple.com/app-store/review/guidelines/
- Apple ScreenCaptureKit: https://developer.apple.com/documentation/screencapturekit
- Apple microphone authorization: https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media
- Apple frontmost application API: https://developer.apple.com/documentation/appkit/nsworkspace/frontmostapplication
- Apple pasteboard API: https://developer.apple.com/documentation/appkit/nspasteboard
- Groq API reference: https://console.groq.com/docs/api-reference
- OpenRouter model API: https://openrouter.ai/docs/api/api-reference/models/list-all-models-and-their-properties
- SambaNova model API: https://docs-prod.sambanova.ai/docs/api-reference/endpoints/model-list
- Cerebras model API: https://inference-docs.cerebras.ai/api-reference/models/list-models
- GNU GPLv3: https://www.gnu.org/licenses/gpl-3.0.html
- GNU GPL FAQ on charging and redistribution: https://www.gnu.org/licenses/gpl-faq.en.html
- GitHub Sponsors fees and taxes: https://docs.github.com/en/sponsors/sponsoring-open-source-contributors/about-sponsorships-fees-and-taxes
- GitHub repository Sponsor button: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/displaying-a-sponsor-button-in-your-repository
- GitHub Discussions and Poll categories: https://docs.github.com/en/discussions/managing-discussions-for-your-community/managing-categories-for-discussions
- GitHub contribution guidelines: https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/setting-guidelines-for-repository-contributors
- Claude for Open Source: https://claude.com/contact-sales/claude-for-oss

## 22. Decisions Locked for MVP

- Product name: Vortext.
- Visual direction: Quiet Utility.
- Native lean modular architecture.
- SwiftUI/AppKit and SwiftData.
- One FluidAudio Parakeet local transcription model.
- Direct provider APIs through URLSession.
- Initial cloud providers: Groq, OpenRouter, SambaNova, Cerebras.
- Default Mode is permanent, local-only, and nondeletable.
- Tabs are History, Models, Modes, Dictionary.
- Context is action-scoped and transparent.
- Provider keys are local-only in device-bound macOS Keychain storage.
- No Vortext server, licensing UI, account, telemetry, or subscription in MVP.
- Source and official binaries are free under GPLv3 with no activation gate.
- Funding is voluntary through GitHub Sponsors and never changes product access or voting power.
- Product direction is proposed and voted on publicly, with documented maintainer safeguards.
- Claude for Open Source is an honest maintainer application goal, not an app feature or API funding source.
