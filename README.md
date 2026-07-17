<p align="right">
  <strong>English</strong> | <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img src="Assets/AppIcon/app-icon-1024.png" width="112" alt="funPaste icon">
</p>

<h1 align="center">funPaste</h1>

<p align="center">
  <strong>Copying is only the beginning.</strong><br>
  Keep clipboard history, reusable content, and prompts one shortcut away.
</p>

<p align="center">
  <a href="https://github.com/rchanggogogo/funPaste/actions/workflows/ci.yml"><img src="https://github.com/rchanggogogo/funPaste/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-FF9F5B.svg" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-121728.svg" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6-F05138.svg" alt="Swift 6">
</p>

<p align="center"><kbd>⇧ Shift</kbd> + <kbd>⌘ Command</kbd> + <kbd>V</kbd></p>

<p align="center">
  <img src="Assets/README/hero.svg" width="100%" alt="funPaste quick-paste panel preview">
</p>

## Why funPaste?

Many clipboard managers turn everything you copy into one long list. funPaste works more like a deck of content cards: recent text, images, files, favorites, and prompts stay together in one keyboard-first panel.

| ⚡ Stay in flow | ✦ Prompts are first-class content | ◉ Local-first |
| --- | --- | --- |
| Press `Shift + Command + V` from any app, select with the arrow keys, and press `Enter` to paste back where you were working. | Save reusable prompts and complete `{{feature description}}` and `{{technical constraints}}` before pasting. | No account, telemetry, ads, or network sync. Your history, prompts, and favorites remain on your Mac. |

## Features

- Records text, image, and file clipboard history and moves duplicates to the top.
- Searches recent clipboard content with fast keyboard navigation.
- Creates, edits, and deletes your own prompts and favorites.
- Favorites recently copied text or images with one click.
- Completes prompt variables before copying or pasting.
- Pauses recording or clears all history at any time.
- Runs as a menu bar agent without taking space in the Dock.
- Automatically uses an English or Simplified Chinese interface based on the preferred macOS language.

## Get started

### Download the beta

funPaste supports Apple silicon and Intel Macs running macOS 14 or later.

1. Download the latest `.dmg` from [Releases](https://github.com/rchanggogogo/funPaste/releases).
2. Drag `funPaste.app` into the Applications folder.
3. On first launch, Control-click the app and choose **Open**. The current beta is not notarized by Apple.
4. Allow funPaste in **System Settings → Privacy & Security → Accessibility**. This permission is used only to paste automatically.

### Run from source

```sh
git clone https://github.com/rchanggogogo/funPaste.git
cd funPaste
swift run FunPastePreview
```

Press `Shift + Command + V` after launch, or run the behavior checks first:

```sh
swift run FunPasteUITestRunner
```

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `Shift + Command + V` | Show or hide the panel |
| `Tab` / `Shift + Tab` | Switch categories |
| `↑` / `↓` | Move the selection |
| `Enter` | Paste the selected content |
| `Esc` | Close the panel |

## Build the macOS app

Create a locally runnable app with an ad-hoc signature:

```sh
bash scripts/build-app.sh
open dist/funPaste.app
```

Create a universal DMG for Apple silicon and Intel Macs:

```sh
bash scripts/build-dmg.sh 1.0.0
```

Public distribution still requires a Developer ID signature and Apple notarization.

## Privacy is not a footnote

funPaste can access the content you copy, so its privacy boundaries should be explicit:

- The app currently makes no network requests and does not write clipboard contents to logs.
- Clipboard history and the content library are persisted through macOS `UserDefaults` without additional app-level encryption.
- Sensitive-content filtering is heuristic and cannot identify every password, token, or piece of personal information.
- Accessibility permission is used only to simulate `Command + V`; without it, you can still copy and paste manually.

See [PRIVACY.md](PRIVACY.md) for the full disclosure.

## Contributing

Bug reports, interaction ideas, and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before getting started. Follow [SECURITY.md](SECURITY.md) for security reports instead of disclosing vulnerabilities in public issues.

## License

funPaste is available under the [MIT License](LICENSE).
