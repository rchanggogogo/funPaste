# Universal DMG and GitHub Release Design

## Goal

Create a free, unsigned test release of funPaste that runs on both Apple Silicon and Intel Macs running macOS 14 or later, and publish it from a private GitHub repository.

## Distribution model

The project distributes an unsigned DMG. Users download the DMG from a private GitHub Release, drag funPaste to Applications, and use Finder's Open action to accept macOS's first-launch warning. The README explains that this is a test build and documents the required Accessibility permission.

This release is intentionally not notarized. It does not require an Apple Developer Program membership and must not claim that Apple has verified the app.

## Build design

The release script builds `FunPastePreview` twice: once for `arm64` and once for `x86_64`. It combines the two executables with `lipo`, inserts that universal executable into `funPaste.app`, signs it ad hoc, verifies the signature and both architectures, then creates a compressed read-only DMG named with the release version.

The script reads the version from an optional first argument and defaults to `1.0.0`. It keeps generated files inside `dist/` so Git does not track release artifacts.

## Continuous integration and delivery

Two GitHub Actions workflows provide separate feedback loops:

- `ci.yml` runs on pull requests and pushes to `main`. It runs the Swift test runner and a universal build smoke test on `macos-14`.
- `release.yml` runs only for pushed tags matching `v*`. It creates the DMG, verifies the result, and attaches it to a GitHub Release. The workflow grants only `contents: write`, which lets its built-in token create the release and upload its asset.

Tag names use the form `v1.0.0`; the script receives the tag without the leading `v` and creates `funPaste-1.0.0.dmg`.

## Documentation and positioning

README gains a concise product introduction and a release section. The primary message is:

> Copying is only the start. funPaste builds prompts in one step and keeps ideas, clipboard history, and reusable instructions within reach. Press Shift + Command + V to search, save, and paste in one flow.

The Chinese README presents the same promise naturally: funPaste 一键构建 Prompt，把灵感、剪贴板和常用指令留在手边。

## Testing

The project keeps its existing Swift UI test runner. Release verification additionally checks that `lipo -archs` reports both `arm64` and `x86_64`, that `codesign --verify` succeeds, and that the DMG exists. GitHub Actions executes these checks independently of the local machine.

## Non-goals

- Apple Developer ID signing and notarization.
- Mac App Store submission.
- Auto-updates or a public download page.
- Releasing a DMG for every development commit.
