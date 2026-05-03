import AppKit
import SwiftUI
import QuickLookUI

@MainActor
final class PopoverController: NSObject {
    private let store: ToteStore
    private let hover = HoverState()
    private let popover = NSPopover()
    private var keyMonitor: Any?
    private var quickLookController: QuickLookController?

    init(store: ToteStore) {
        self.store = store
        super.init()
        let view = PopoverView(store: store, hover: hover)
        let host = NSHostingController(rootView: view)
        // Without this, NSHostingController reports a default ~480x320
        // and NSPopover renders an oversized bubble around the actual
        // SwiftUI content. Opting in makes it track the SwiftUI
        // intrinsic size automatically.
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true
    }

    func toggle(relativeTo view: NSView) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
            installKeyMonitor()
        }
    }

    func dismiss() {
        popover.performClose(nil)
    }

    /// While the popover is open, intercept spacebar locally (so it
    /// doesn't bubble up to whatever app was previously active) and
    /// show QuickLook for the row currently under the cursor.
    private func installKeyMonitor() {
        if keyMonitor != nil { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // 49 = spacebar.
            if event.keyCode == 49, let url = self.hover.hoveredURL {
                self.openQuickLook(url: url)
                return nil
            }
            return event
        }
        // Also tear down the monitor when the popover closes.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(popoverDidClose),
            name: NSPopover.didCloseNotification,
            object: popover
        )
    }

    @objc private func popoverDidClose() {
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
        quickLookController?.close()
        quickLookController = nil
        NotificationCenter.default.removeObserver(self, name: NSPopover.didCloseNotification, object: popover)
    }

    private func openQuickLook(url: URL) {
        let controller = quickLookController ?? QuickLookController()
        quickLookController = controller
        controller.preview(url: url)
    }
}
