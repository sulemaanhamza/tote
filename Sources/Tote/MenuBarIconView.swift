import AppKit

/// Transparent overlay that sits inside `NSStatusItem.button`. It owns
/// nothing visual — the button's own image is what the user sees. This
/// view exists only because you can't subclass NSStatusBarButton, so
/// dropping a custom NSView on top is the only way to:
///
/// 1. **Drop in** — accept file URLs dragged onto the menu bar icon.
/// 2. **Click out** — quick click toggles the popover.
/// 3. **Drag out** — press-and-drag picks up the top entry and starts a
///    real Cocoa dragging session.
/// 4. **Right click** — surface the context menu.
///
/// All visual changes (empty vs filled glyph, halo on drag-over, scale
/// pulse on add) happen on the button itself, owned by MenuBarController.
@MainActor
final class MenuBarIconView: NSView, NSDraggingSource {
    private let topURLForDrag: () -> URL?
    private let onDropFiles: ([URL]) -> Void
    private let onDragEnter: () -> Void
    private let onDragExit: () -> Void
    private let onClick: () -> Void
    private let onRightClick: () -> Void

    private var pressOrigin: NSPoint?
    private var didBeginOutgoingDrag = false
    private static let dragThreshold: CGFloat = 4.0

    init(
        frame: NSRect,
        topURLForDrag: @escaping () -> URL?,
        onDropFiles: @escaping ([URL]) -> Void,
        onDragEnter: @escaping () -> Void,
        onDragExit: @escaping () -> Void,
        onClick: @escaping () -> Void,
        onRightClick: @escaping () -> Void
    ) {
        self.topURLForDrag = topURLForDrag
        self.onDropFiles = onDropFiles
        self.onDragEnter = onDragEnter
        self.onDragExit = onDragExit
        self.onClick = onClick
        self.onRightClick = onRightClick
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// We're transparent on purpose, but we still need to be the hit-test
    /// target for the button's area so mouseDown reaches us before the
    /// underlying NSStatusBarButton.
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    // MARK: - Drop in (NSDraggingDestination)

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasFileURLs(sender) else { return [] }
        onDragEnter()
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExit()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = readFileURLs(sender)
        guard !urls.isEmpty else {
            onDragExit()
            return false
        }
        onDropFiles(urls)
        return true
    }

    private func hasFileURLs(_ info: NSDraggingInfo) -> Bool {
        info.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ])
    }

    private func readFileURLs(_ info: NSDraggingInfo) -> [URL] {
        let opts: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: opts) as? [URL] ?? []
    }

    // MARK: - Click vs press-and-drag

    override func mouseDown(with event: NSEvent) {
        pressOrigin = event.locationInWindow
        didBeginOutgoingDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !didBeginOutgoingDrag, let origin = pressOrigin else { return }
        let p = event.locationInWindow
        let dx = p.x - origin.x, dy = p.y - origin.y
        guard dx * dx + dy * dy >= MenuBarIconView.dragThreshold * MenuBarIconView.dragThreshold else { return }
        startOutgoingDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        defer { pressOrigin = nil }
        if didBeginOutgoingDrag { return }
        onClick()
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick()
    }

    private func startOutgoingDrag(with event: NSEvent) {
        guard let url = topURLForDrag() else { return }
        didBeginOutgoingDrag = true

        let draggingItem = NSDraggingItem(pasteboardWriter: url as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)

        let cursorInView = convert(event.locationInWindow, from: nil)
        let imageRect = NSRect(
            x: cursorInView.x - 16,
            y: cursorInView.y - 16,
            width: 32,
            height: 32
        )
        draggingItem.setDraggingFrame(imageRect, contents: icon)

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    // MARK: - NSDraggingSource

    nonisolated func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        switch context {
        case .outsideApplication: return [.copy, .generic, .link]
        case .withinApplication: return [.copy]
        @unknown default: return [.copy]
        }
    }
}
