# Vortext

A small, native macOS voice utility. Vortext records speech, transcribes it locally, optionally improves or answers it with a cloud model you choose, and inserts the result into the active application.

- **Local first.** Transcription runs on-device with a Parakeet model via FluidAudio. The Default Mode works offline and never contacts a server.
- **Bring your own key.** Optional cloud Modes use your own Groq, OpenRouter, SambaNova, or Cerebras API key, stored only in the macOS Keychain.
- **Action-scoped context.** Clipboard, frontmost app, time, and screen context are captured only when you trigger an action, shown in the recorder, and never retained.
- **No accounts.** No license gate, subscription, telemetry, or backend.

## Privacy summary

| Data | Where it goes |
|---|---|
| Audio | Recorded locally, kept with its History entry until you delete it |
| Transcripts | Stored locally in History (editable, deletable) |
| API keys | macOS Keychain, device-only, never synced |
| Clipboard / screenshots | Sent only to your chosen provider for cloud Modes, never persisted |
| Telemetry | None |

## Requirements

- macOS 15.0 or later, Apple silicon
- Xcode 26.1+ to build from source

## Build from source

```bash
brew install xcodegen
git clone https://github.com/Shino0u0/Vortext.git
cd Vortext
xcodegen generate
open Vortext.xcodeproj
```

Run the `Vortext` scheme. Tests: `xcodebuild test -scheme Vortext -destination 'platform=macOS'`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Feature direction is decided in public: proposals start in GitHub Discussions, mature ones go to a community poll, accepted ones become scoped issues anyone can implement. See [GOVERNANCE.md](GOVERNANCE.md).

## License

GPLv3. See [LICENSE](LICENSE). Official binaries are free, with no activation or license check. Sponsorship is voluntary and never gates features.
