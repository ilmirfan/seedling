import Foundation

enum Destination: String, Codable, CaseIterable { case automatic = "Automatic", movie = "Movie", other = "Other" }
struct TorrentFile: Codable { var name: String; var length: Int64; var bytesCompleted: Int64 }
struct Transfer: Codable, Identifiable {
    var id: Int; var hashString: String; var name: String; var status: Int
    var totalSize: Int64; var haveValid: Int64; var haveUnchecked: Int64; var leftUntilDone: Int64
    var percentDone: Double; var metadataPercentComplete: Double; var rateDownload: Int64; var rateUpload: Int64
    var error: Int; var errorString: String; var downloadDir: String; var eta: Int
    var peers: [Peer]; var files: [TorrentFile]; var recheckProgress: Double
    struct Peer: Codable { var progress: Double }
    var seeds: Int { peers.filter { $0.progress >= 1 }.count }
    var leeches: Int { peers.count - seeds }
    var complete: Bool {
        metadataPercentComplete >= 1 && totalSize > 0 && leftUntilDone == 0 && haveUnchecked == 0 && haveValid >= totalSize && error == 0 && ![1,2].contains(status) && !files.isEmpty && files.allSatisfy { $0.bytesCompleted == $0.length }
    }
    var movie: Bool { MovieClassifier.isMovie(name: name, files: files) }
    static let fields = ["id","hashString","name","status","totalSize","haveValid","haveUnchecked","leftUntilDone","percentDone","metadataPercentComplete","rateDownload","rateUpload","error","errorString","downloadDir","eta","peers","files","recheckProgress"]
}
enum MovieClassifier {
    static func isMovie(name: String, files: [TorrentFile]) -> Bool {
        let video = Set(["mkv","mp4","avi","mov","m4v","webm","mpg","mpeg","m2ts"])
        let relevant = files.filter { video.contains(URL(fileURLWithPath:$0.name).pathExtension.lowercased()) && !$0.name.lowercased().contains("sample") }
        guard !relevant.isEmpty else { return false }
        let titles = ([name] + relevant.map(\.name)).joined(separator:" ")
        if titles.range(of: #"(?i)(\bS\d{1,2}E\d{1,3}\b|\b\d{1,2}x\d{2}\b|\bseason[ ._-]*\d+\b|\bepisode[ ._-]*\d+\b)"#,options:.regularExpression) != nil { return false }
        return relevant.count == 1
    }
}
struct Preferences: Codable {
    var movieFolder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies").path
    var otherFolder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
    var removeCompleted = true
    var destinations: [String: Destination] = [:]
}
func byteString(_ n: Int64) -> String { ByteCountFormatter.string(fromByteCount:n,countStyle:.file) }
