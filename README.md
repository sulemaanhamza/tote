# Stash

A file clipboard for the macOS menu bar. Drag a file onto the menu bar icon — it's stashed. Drag from the icon — drops anywhere. Solves the "I want this file in Slack but Slack is in another Space and the drag-and-drop reveals my desktop" problem.

No folders, no rename, no search. Last 5 files.

## Install

**Homebrew**

```sh
brew tap sulemaanhamza/stash
brew install --cask stash
xattr -d com.apple.quarantine /Applications/Stash.app
```

**Direct download**

Grab the latest zip from [Releases](https://github.com/sulemaanhamza/stash/releases), unzip, drag `Stash.app` to `/Applications`, then:

```sh
xattr -d com.apple.quarantine /Applications/Stash.app
```

The `xattr` step is needed because Stash isn't signed with an Apple Developer ID — it tells macOS the app is safe to open.

## Build from source

```sh
git clone https://github.com/sulemaanhamza/stash.git
cd stash
swift run
```

Or build a proper app bundle:

```sh
./scripts/build-app.sh 0.1.0
open build/Stash.app
```

## How it works

- **Drag onto the icon** — the file is added to the tray (top of the list, max 5).
- **Click the icon** — opens the popover with the 5 most recent files.
- **Drag a row out** — drops the file wherever you release.
- **Click and hold the icon, then drag** — instant drag of the most recent file. The fast path.
- **Spacebar over a row** — Quick Look preview.
- **Right-click a row** — Show in Finder, or Remove.
- **Right-click the icon** — Launch at Login, About, Quit.

Stash stores file references (bookmarks), not copies. If you move or delete the source file, the row dims with a red dot and won't drag — that's the intended failure mode.

## Run tests

```sh
swift run Stash --test
```

## License

MIT — see [LICENSE](LICENSE).
