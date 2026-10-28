import Foundation

/// Moves the previous app's complete private state with a same-volume rename.
/// Download payloads stay in the user's selected folders. To roll back, quit
/// Seedling and rename this private state directory to its previous name.
enum SeedlingStorage {
    struct MigrationError:LocalizedError {
        let message:String
        var errorDescription:String? {message}
    }
    static func resolve(base:URL,override:String? = nil,previousAppRunning:Bool = false) throws -> URL {
        if let override {return URL(fileURLWithPath:override,isDirectory:true)}
        let destination=base.appendingPathComponent("Seedling",isDirectory:true)
        let previous=base.appendingPathComponent("Ayra",isDirectory:true) // Previous release's on-disk name.
        let fm=FileManager.default
        if !fm.fileExists(atPath:destination.path),fm.fileExists(atPath:previous.path) {
            guard !previousAppRunning else {
                throw MigrationError(message:"Quit the previous app version, then reopen Seedling to preserve your download state safely.")
            }
            do {try fm.moveItem(at:previous,to:destination)}
            catch {throw MigrationError(message:"Seedling could not move your existing app data: \(error.localizedDescription). No new download session was started.")}
        }
        return destination
    }
}
