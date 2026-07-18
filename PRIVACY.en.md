# Privacy Statement

funPaste is a local-first clipboard tool. The current version has no account system, telemetry, analytics, advertising, or network sync, and does not intentionally send clipboard content to network services.

## Data processed locally

funPaste reads text, images, and file references from the macOS clipboard and keeps recent history entries on the Mac. The default limit is 200 entries, and you can choose a limit from 50 to 2,000. Prompts, favorites, pause state, and clipboard history are persisted through macOS `UserDefaults`; funPaste does not currently add application-level encryption to that data.

You can pause clipboard recording or clear all clipboard history from the menu bar at any time. Uninstalling the application may not automatically remove preferences stored by macOS.

## Sensitive content

funPaste uses a limited set of English and Chinese keywords to skip content that may contain passwords, verification codes, or bank-card information. This heuristic is not a complete security boundary and may miss passwords, access tokens, private keys, personal information, or other sensitive content. Do not rely on it to protect confidential data.

## System permissions

funPaste requests macOS Accessibility permission only to simulate `Command + V` after you choose an item, returning it to the application you were using. If you deny the permission, clipboard recording and copying remain available, but you must paste manually.

## Network and logs

The current application code makes no network requests. Runtime logs record panel, shortcut, permission, and paste-flow status, but do not record clipboard content.

This statement will be updated with the relevant release if the application's privacy behavior changes.
