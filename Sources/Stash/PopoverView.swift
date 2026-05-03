import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PopoverView: View {
    @ObservedObject var store: StashStore
    /// Owned by the AppDelegate; we publish the hovered URL so the QL
    /// monitor can preview it on spacebar.
    @ObservedObject var hover: HoverState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.entries.isEmpty {
                emptyState
            } else {
                ForEach(store.entries) { entry in
                    StashRow(entry: entry, store: store, hover: hover)
                    if entry.id != store.entries.last?.id {
                        Divider().opacity(0.3)
                    }
                }
            }
        }
        .padding(8)
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            Text("Drag a file onto the icon.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 16)
    }
}

/// Mutable bag the popover and the AppDelegate both touch — the SwiftUI
/// view writes the hovered URL on hover; the AppKit-side QuickLook
/// monitor reads it when spacebar is pressed.
@MainActor
final class HoverState: ObservableObject {
    @Published var hoveredURL: URL?
}

private struct StashRow: View {
    let entry: StashEntry
    @ObservedObject var store: StashStore
    @ObservedObject var hover: HoverState

    @State private var isHovered = false

    private var resolvedURL: URL? { store.resolveURL(for: entry) }
    private var isAlive: Bool { resolvedURL != nil }

    var body: some View {
        HStack(spacing: 10) {
            iconImage
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.displayName)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if !isAlive {
                        Circle()
                            .fill(Color.red.opacity(0.7))
                            .frame(width: 6, height: 6)
                    }
                }
                Text(entry.displayPath)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 0)
            // Reveal the remove affordance only on hover so the row stays
            // visually quiet by default. Right-click → Remove is still
            // available via contextMenu for keyboard / no-hover cases.
            removeButton
                .opacity(isHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
        )
        .opacity(isAlive ? 1.0 : 0.5)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            hover.hoveredURL = hovering ? resolvedURL : nil
        }
        .onDrag {
            guard let url = resolvedURL else { return NSItemProvider() }
            return NSItemProvider(object: url as NSURL)
        }
        .contextMenu {
            Button("Show in Finder") {
                if let url = resolvedURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            .disabled(!isAlive)
            Button("Remove") { store.remove(id: entry.id) }
        }
    }

    private var removeButton: some View {
        Button {
            store.remove(id: entry.id)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)
        .help("Remove from Stash")
    }

    private var iconImage: some View {
        Group {
            if let url = resolvedURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "doc")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.secondary)
                    .padding(4)
            }
        }
    }
}
