import AppKit

/// In-process smoke tests for Stash's pure logic (no NSApplication
/// needed). Run with: `swift run Stash --test`.
enum SelfTests {
    /// Mutable bag the test functions share. A class so the closures
    /// passed to `MainActor.assumeIsolated` can mutate it without
    /// inout dance.
    final class Runner {
        var passed = 0
        var failures: [String] = []

        func check(_ name: String, _ assertion: @autoclosure () -> Bool) {
            if assertion() {
                passed += 1
            } else {
                failures.append(name)
                print("✗ \(name)")
            }
        }
    }

    @MainActor
    static func run() -> Never {
        let r = Runner()

        runMergeTests(r)
        runLaunchAtLoginTests(r)
        runStoreLifecycleTests(r)

        let total = r.passed + r.failures.count
        print("\n\(r.passed)/\(total) passed")
        if !r.failures.isEmpty {
            print("\(r.failures.count) failure(s):")
            for f in r.failures { print("  · \(f)") }
            exit(1)
        }
        exit(0)
    }

    // MARK: - Merge (pure logic, no actor)

    private static func runMergeTests(_ r: Runner) {
        let cap = 5

        let empty: [StashEntry] = []
        r.check("merge nothing into nothing → empty",
                StashStore.merge(adding: [], into: empty, capacity: cap).isEmpty)

        let a = makeSyntheticEntry(name: "a.txt", path: "/tmp")
        let b = makeSyntheticEntry(name: "b.txt", path: "/tmp")
        let c = makeSyntheticEntry(name: "c.txt", path: "/tmp")
        let d = makeSyntheticEntry(name: "d.txt", path: "/tmp")
        let e = makeSyntheticEntry(name: "e.txt", path: "/tmp")
        let f = makeSyntheticEntry(name: "f.txt", path: "/tmp")

        let one = StashStore.merge(adding: [a], into: [], capacity: cap)
        r.check("single add length", one.count == 1)
        r.check("single add identity", one.first?.displayName == "a.txt")

        let abThenC = StashStore.merge(adding: [c], into: [b, a], capacity: cap)
        r.check("newest at top: c first", abThenC.first?.displayName == "c.txt")
        r.check("newest at top: b second", abThenC[1].displayName == "b.txt")
        r.check("newest at top: a last", abThenC[2].displayName == "a.txt")

        let overflow = StashStore.merge(adding: [f], into: [e, d, c, b, a], capacity: cap)
        r.check("overflow length capped", overflow.count == cap)
        r.check("overflow keeps newest", overflow.first?.displayName == "f.txt")
        r.check("overflow drops oldest", !overflow.contains(where: { $0.displayName == "a.txt" }))

        let aDup = makeSyntheticEntry(name: "a.txt", path: "/tmp")
        let bumped = StashStore.merge(adding: [aDup], into: [c, b, a], capacity: cap)
        r.check("re-stash dedupes by path", bumped.count == 3)
        r.check("re-stash bumps to top", bumped.first?.displayName == "a.txt")
        r.check("re-stash preserves others",
                Set(bumped.map(\.displayName)) == ["a.txt", "b.txt", "c.txt"])

        let multi = StashStore.merge(adding: [c, b, a], into: [], capacity: cap)
        r.check("multi-add order: first → top",
                multi.map(\.displayName) == ["c.txt", "b.txt", "a.txt"])

        let batchDup = StashStore.merge(adding: [a, a, a], into: [], capacity: cap)
        r.check("same-batch dedupe", batchDup.count == 1)

        let aOther = makeSyntheticEntry(name: "a.txt", path: "/elsewhere")
        let twoFolders = StashStore.merge(adding: [aOther], into: [a], capacity: cap)
        r.check("path disambiguates same name", twoFolders.count == 2)

        r.check("capacity == 5", StashStore.capacity == 5)
        r.check("pathKey joins path + name", a.pathKey == "/tmp/a.txt")
    }

    // MARK: - LaunchAtLogin

    private static func runLaunchAtLoginTests(_ r: Runner) {
        let launchBefore = LaunchAtLogin.isEnabled
        r.check("LaunchAtLogin.isEnabled returns Bool",
                launchBefore == true || launchBefore == false)
        LaunchAtLogin.setEnabled(launchBefore)
        r.check("LaunchAtLogin.setEnabled(current) is no-op",
                LaunchAtLogin.isEnabled == launchBefore)
    }

    // MARK: - StashStore lifecycle (real bookmarks, real persistence)

    @MainActor
    private static func runStoreLifecycleTests(_ r: Runner) {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory
            .appendingPathComponent("stash-tests-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempRoot) }

        // Real files so URL.bookmarkData() succeeds.
        let fileA = tempRoot.appendingPathComponent("alpha.txt")
        let fileB = tempRoot.appendingPathComponent("beta.txt")
        let fileC = tempRoot.appendingPathComponent("gamma.txt")
        try? "alpha".write(to: fileA, atomically: true, encoding: .utf8)
        try? "beta".write(to: fileB, atomically: true, encoding: .utf8)
        try? "gamma".write(to: fileC, atomically: true, encoding: .utf8)

        let storeFile = tempRoot.appendingPathComponent("entries.json")

        // --- add() inserts entries with newest first ---
        let s1 = StashStore(storeURL: storeFile)
        r.check("fresh store is empty", s1.entries.isEmpty)

        s1.add(urls: [fileA])
        r.check("add(1) → 1 entry", s1.entries.count == 1)
        r.check("add stored display name",
                s1.entries.first?.displayName == "alpha.txt")

        s1.add(urls: [fileB, fileC])
        r.check("add(more) → newest first",
                s1.entries.map(\.displayName) == ["beta.txt", "gamma.txt", "alpha.txt"])

        // --- resolveURL round-trips to the real file ---
        if let entry = s1.entries.first(where: { $0.displayName == "alpha.txt" }),
           let resolved = s1.resolveURL(for: entry) {
            r.check("resolveURL round-trips path",
                    resolved.standardizedFileURL == fileA.standardizedFileURL)
        } else {
            r.check("resolveURL round-trips path", false)
        }

        // --- persistence: a fresh store at the same path sees the same entries ---
        let s2 = StashStore(storeURL: storeFile)
        r.check("persistence: count survives reload",
                s2.entries.count == 3)
        r.check("persistence: order survives reload",
                s2.entries.map(\.displayName) == ["beta.txt", "gamma.txt", "alpha.txt"])

        // --- remove() drops the row and persists ---
        if let toRemove = s2.entries.first(where: { $0.displayName == "gamma.txt" }) {
            s2.remove(id: toRemove.id)
        }
        r.check("remove drops entry", s2.entries.count == 2)
        r.check("remove keeps the right ones",
                Set(s2.entries.map(\.displayName)) == ["beta.txt", "alpha.txt"])

        let s3 = StashStore(storeURL: storeFile)
        r.check("remove persists across reload",
                Set(s3.entries.map(\.displayName)) == ["beta.txt", "alpha.txt"])

        // --- resolveURL on a deleted file returns nil (dead-row UX) ---
        try? fm.removeItem(at: fileA)
        if let entry = s3.entries.first(where: { $0.displayName == "alpha.txt" }) {
            r.check("resolveURL nil after source deleted",
                    s3.resolveURL(for: entry) == nil)
        } else {
            r.check("resolveURL nil after source deleted", false)
        }

        // --- clear() empties + persists ---
        s3.clear()
        r.check("clear empties store", s3.entries.isEmpty)
        let s4 = StashStore(storeURL: storeFile)
        r.check("clear persists across reload", s4.entries.isEmpty)

        // --- add() with no URLs is a no-op (defensive against empty drops) ---
        let beforeNoop = s4.entries
        s4.add(urls: [])
        r.check("add(empty) is no-op", s4.entries == beforeNoop)
    }

    // MARK: - helpers

    /// For pure-logic merge tests where the bookmark blob is irrelevant.
    private static func makeSyntheticEntry(name: String, path: String) -> StashEntry {
        StashEntry(
            bookmark: Data(),
            displayName: name,
            displayPath: path,
            addedAt: Date()
        )
    }
}
