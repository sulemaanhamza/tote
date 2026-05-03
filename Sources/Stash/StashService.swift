import AppKit

/// Backs the macOS NSServices entry declared in `Info.plist` (added by
/// `scripts/build-app.sh`). Surfaces "Stash" in the right-click menu for
/// any file selection — Finder, most editors, mail attachments. The user
/// can also assign a keyboard shortcut via System Settings → Keyboard →
/// Keyboard Shortcuts → Services, which is arguably the killer path:
/// select a file anywhere, press the shortcut, file is stashed.
///
/// The selector signature is fixed by the NSServices ABI.
@MainActor
final class StashService: NSObject {
    private let store: StashStore

    init(store: StashStore) {
        self.store = store
        super.init()
    }

    @objc func stashFiles(
        _ pboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>?
    ) {
        let opts: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = (pboard.readObjects(forClasses: [NSURL.self], options: opts) as? [URL]) ?? []
        guard !urls.isEmpty else {
            error?.pointee = "No files selected" as NSString
            return
        }
        store.add(urls: urls)
    }
}
