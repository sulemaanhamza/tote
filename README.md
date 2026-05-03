# Tote

A file clipboard for the macOS menu bar. Drag a file onto the menu bar icon — it's in your tote. Drag from the icon — drops anywhere. Solves the "I want this file in Slack but Slack is in another Space and the drag-and-drop reveals my desktop" problem.

No folders, no rename, no search. Last 5 files.

## Install

**Homebrew**

```sh
brew tap sulemaanhamza/tote
brew install --cask sulemaanhamza/tote/tote
xattr -d com.apple.quarantine /Applications/Tote.app
```

The tap-qualified name (`sulemaanhamza/tote/tote`) avoids any future name collisions with other casks.

**Direct download**

Grab the latest zip from [Releases](https://github.com/sulemaanhamza/tote/releases), unzip, drag `Tote.app` to `/Applications`, then:

```sh
xattr -d com.apple.quarantine /Applications/Tote.app
```

The `xattr` step is needed because Tote isn't signed with an Apple Developer ID — it tells macOS the app is safe to open.

## Build from source

```sh
git clone https://github.com/sulemaanhamza/tote.git
cd tote
swift run
```

Or build a proper app bundle:

```sh
./scripts/build-app.sh 0.1.2
open build/Tote.app
```

## How it works

- **Drag onto the icon** — the file is added to the tote (top of the list, max 5).
- **Click the icon** — opens the popover with the 5 most recent files.
- **Drag a row out** — drops the file wherever you release.
- **Click and hold the icon, then drag** — instant drag of the most recent file. The fast path.
- **Right-click any file in Finder → Tote** (or under *Services*) — adds the file without dragging. Assign it a keyboard shortcut in System Settings → Keyboard → Keyboard Shortcuts → Services for the fastest path.
- **Spacebar over a row** — Quick Look preview.
- **Right-click a row** — Show in Finder, or Remove.
- **Right-click the icon** — Launch at Login, About, Quit.

Tote stores file references (bookmarks), not copies. If you move or delete the source file, the row dims with a red dot and won't drag — that's the intended failure mode.

## Run tests

```sh
swift run Tote --test
```

## License

MIT — see [LICENSE](LICENSE).
