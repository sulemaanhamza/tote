import AppKit
import QuickLookUI

/// Wraps the shared QLPreviewPanel so we can drive it with a single URL
/// at a time. The panel keeps a strong reference to its data source, so
/// we hold this controller for the lifetime of the popover that opened
/// the preview.
@MainActor
final class QuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private var url: URL?

    func preview(url: URL) {
        self.url = url
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func close() {
        guard let panel = QLPreviewPanel.shared(), panel.isVisible else { return }
        panel.orderOut(nil)
    }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        // Fast path: caller sets one URL at a time.
        return 1
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        // Hop to the main actor synchronously to read `url`. `index` is
        // always 0 because numberOfPreviewItems returns 1.
        MainActor.assumeIsolated {
            (url ?? URL(fileURLWithPath: "/")) as NSURL
        }
    }
}
