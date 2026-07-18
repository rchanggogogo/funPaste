# Repository Guidelines

## Project Structure & Module Organization

funPaste is a Swift 6 package targeting macOS 14 and later. Core models, clipboard behavior, panel controllers, and SwiftUI views live in `Sources/FunPasteUI/`. `Sources/FunPastePreview/` contains the runnable menu-bar app entry point, while `Sources/FunPasteUITestRunner/` contains the repository's executable test harness. Release integration checks are in `Tests/release-build-tests.sh`.

App icons belong in `Assets/AppIcon/`. Packaging and icon-generation utilities live in `scripts/`; generated `.build*` and `dist/` content must remain untracked. Browser-preview files are under `preview/`, implementation notes under `docs/plans/`, and project policies are documented in `CONTRIBUTING.md`, `PRIVACY.md`, and `SECURITY.md`. GitHub Actions automation lives in `.github/workflows/`: `ci.yml` validates pushes and pull requests, while `release.yml` packages tags matching `v*`.

## Build, Test, and Development Commands

- `swift build`: compile all package targets in debug mode.
- `swift run FunPastePreview`: launch funPaste locally; use `Shift + Command + V` to open the panel.
- `swift run FunPasteUITestRunner`: run the Swift behavior and UI-state checks.
- `bash scripts/make-icon.sh`: regenerate `AppIcon.icns` and the iconset PNGs from `Assets/AppIcon/app-icon-1024.png`.
- `bash scripts/build-app.sh`: create the local ad-hoc-signed `dist/funPaste.app`.
- `bash scripts/build-dmg.sh 1.0.0`: build arm64 and x86_64 binaries and package a universal DMG.
- `bash Tests/release-build-tests.sh`: verify both architectures, code signing, and DMG creation.
- `git diff --check`: catch whitespace errors before committing.

Run release commands on macOS with the Xcode/Swift 6 toolchain installed.

## Coding Style & Naming Conventions

Use four-space indentation and follow Swift API Design Guidelines. Name types and protocols with `UpperCamelCase`; use `lowerCamelCase` for methods, properties, and local values. Keep files focused and normally named after their primary type, such as `ClipboardStore.swift`. Prefer small value types and explicit dependencies over global mutable state. No formatter is configured, so match surrounding code and run `git diff --check` before committing.

## Testing Guidelines

Add deterministic checks to `FunPasteUITestRunner` for application behavior. Extend the shell release test when changing bundling, signing, architectures, or DMG layout. Tests must not depend on existing clipboard history or user preferences. There is no numeric coverage threshold; every behavior change should include a regression check. At minimum, run `swift run FunPasteUITestRunner` and `git diff --check`; also run `bash Tests/release-build-tests.sh` for release-related changes.

## Commit & Pull Request Guidelines

Follow the existing concise prefixes: `feat:`, `fix:`, `docs:`, `build:`, and `ci:`. Write imperative, single-purpose subjects, for example `fix: restore paste target before posting command`.

Pull requests should explain the user-visible change, list verification commands, and link relevant issues or planning documents. Include screenshots or a short recording for panel or interaction changes. Do not commit generated apps, DMGs, caches, credentials, or signing material. Version tags use the `v<major>.<minor>.<patch>` form; pushing one triggers the release workflow and publishes the generated DMG.
