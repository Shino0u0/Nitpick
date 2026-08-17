# Contributing to Vortext

## Development setup

1. Install Xcode 26.1+ and `brew install xcodegen`.
2. `xcodegen generate` at the repo root produces `Vortext.xcodeproj` (not committed).
3. Run tests with `xcodebuild test -scheme Vortext -destination 'platform=macOS'`.

## Issue flow

- Bugs: file a bug report issue with reproduction steps.
- Features: start in the Discussions `Ideas` category. Features reach implementable Issues only through the process in [GOVERNANCE.md](GOVERNANCE.md). Pull requests for unaccepted features may be declined regardless of quality.

## Pull requests

- Target the default branch; it is protected and requires review.
- Include tests for behavior changes. Provider parsing tests use sanitized fixtures only.
- Never include live API keys in code, fixtures, issues, logs, or recordings.
- Changes to Keychain, permissions, provider transmission, screen capture, signing, or release tooling require review from the designated owner (see CODEOWNERS).
- State the privacy impact of your change in the PR description.

## Expectations

Be respectful (see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)). Small, focused PRs merge faster.
