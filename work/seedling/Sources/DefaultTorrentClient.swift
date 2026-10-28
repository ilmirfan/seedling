import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor final class DefaultTorrentClient: ObservableObject {
    @Published private(set) var handlesMagnets = false
    @Published private(set) var handlesTorrentFiles = false
    @Published private(set) var updating = false
    @Published var error: String?

    private let torrentType = UTType(importedAs: "org.bittorrent.torrent")
    var isDefault: Bool { handlesMagnets && handlesTorrentFiles }

    func refresh() {
        let workspace = NSWorkspace.shared
        handlesMagnets = isThisApp(workspace.urlForApplication(toOpen: URL(string: "magnet:")!))
        handlesTorrentFiles = isThisApp(workspace.urlForApplication(toOpen: torrentType))
    }

    private func isThisApp(_ url: URL?) -> Bool {
        url?.resolvingSymlinksInPath().standardizedFileURL == Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL
    }

    func makeDefault() async {
        guard !updating else { return }
        updating = true
        error = nil
        defer { updating = false }
        refresh()
        var failures: [String] = []
        // Each association can require its own macOS confirmation. Keep the
        // requests sequential and verify the actual result after each one.
        if !handlesMagnets {
            var reason: String?
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "magnet")
            } catch { reason = error.localizedDescription }
            refresh()
            if !handlesMagnets { failures.append("Magnet links: " + (reason ?? "macOS kept the current default.")) }
        }
        if !handlesTorrentFiles {
            var reason: String?
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: torrentType)
            } catch { reason = error.localizedDescription }
            refresh()
            if !handlesTorrentFiles { failures.append("Torrent files: " + (reason ?? "macOS kept the current default.")) }
        }
        if !failures.isEmpty { error = failures.joined(separator: "\n\n") }
    }
}
