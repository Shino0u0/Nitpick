# Security Policy

## Reporting a vulnerability

Use GitHub's private vulnerability reporting on this repository (Security tab, "Report a vulnerability"). Do not open public issues for exploitable problems. You will receive an acknowledgment within 7 days.

## Supported versions

Only the latest release receives security fixes.

## Scope notes

Nitpick stores provider API keys in the macOS Keychain with device-only, unlocked-only accessibility. Keychain protects credentials at rest on an uncompromised Mac; Nitpick does not claim protection against administrator-level malware, keyloggers, provider compromise, or live process-memory inspection. Reports about prompt injection through clipboard, app, or screen context are in scope: Nitpick treats that content as untrusted data but does not represent its mitigations as a complete guarantee.
