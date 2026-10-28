import AppKit
import UniformTypeIdentifiers

// Read-only integration check. Run after choosing Make Default in the app.
// Pass the installed app path; this never changes associations or starts downloads.
@main struct DefaultClientChecks {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            fatalError("Pass the installed Seedling.app path")
        }
        let expected = URL(fileURLWithPath: CommandLine.arguments[1]).resolvingSymlinksInPath().standardizedFileURL
        let workspace = NSWorkspace.shared
        func require(_ actual: URL?, _ label: String) {
            guard actual?.resolvingSymlinksInPath().standardizedFileURL == expected else {
                fatalError("FAIL: \(label) resolves to \(actual?.path ?? "no app")")
            }
            print("PASS: \(label) opens \(expected.path)")
        }
        require(workspace.urlForApplication(toOpen: URL(string: "magnet:")!), "magnet links")
        require(workspace.urlForApplication(toOpen: UTType(importedAs: "org.bittorrent.torrent")), "torrent content type")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("torrent")
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        require(workspace.urlForApplication(toOpen: file), ".torrent file")
    }
}
