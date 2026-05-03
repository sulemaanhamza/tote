import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = StashStore()
    private let updater = Updater()
    private var menuBar: MenuBarController?
    private var popover: PopoverController?
    private var service: StashService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let pop = PopoverController(store: store)
        popover = pop

        menuBar = MenuBarController(
            store: store,
            updater: updater,
            onClick: { [weak self] in
                guard let anchor = self?.menuBar?.anchorView else { return }
                pop.toggle(relativeTo: anchor)
            },
            currentLaunchAtLogin: { LaunchAtLogin.isEnabled },
            onToggleLaunchAtLogin: { LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled) },
            onShowAbout: { [weak self] in
                pop.dismiss()
                self?.showStandardAboutPanel()
            }
        )

        // Register as a system Service ("Stash" in the right-click menu
        // for file selections). NSUpdateDynamicServices nudges the
        // services daemon (pbs) to re-scan our Info.plist; without it,
        // the menu entry can take a logout/login to appear on first run.
        let svc = StashService(store: store)
        service = svc
        NSApp.servicesProvider = svc
        NSUpdateDynamicServices()

        Task { await updater.check() }
    }

    /// Re-launching while running (Spotlight, Finder double-click) hits
    /// this. Open the popover so the user sees what their click did.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard let anchor = menuBar?.anchorView else { return true }
        popover?.toggle(relativeTo: anchor)
        return true
    }

    private func showStandardAboutPanel() {
        let credits = NSAttributedString(
            string: """
            A file clipboard for the macOS menu bar — drag in, drag out.

            MIT licensed. Source at github.com/sulemaanhamza/stash.
            """,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Stash",
            .applicationVersion: version,
            .credits: credits,
            .init(rawValue: "Copyright"): "© 2026 Suleman Hamza",
        ])
    }
}
