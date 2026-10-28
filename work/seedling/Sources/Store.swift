import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor final class SeedlingStore: ObservableObject {
    @Published var transfers: [Transfer] = []
    @Published var preferences = Preferences()
    @Published var error: String?
    @Published var ready = false
    @Published var showAdd = false
    @Published var pendingMagnet = ""
    @Published var verifying: Set<String> = []
    @Published var verified: Set<String> = []
    @Published var isDropping = false
    private var verificationStarted: [String:Date] = [:]
    private var timer: Task<Void,Never>?
    private var polling = false
    private var routed: Set<String> = []
    private var pendingURLs:[URL] = []
    private var migrationBlocked=false
    let root: URL
    let engine: TorrentEngine
    init() {
        let base=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
        let resolved:URL
        var migrationProblem:String?
        do {
            resolved=try SeedlingStorage.resolve(base:base,override:ProcessInfo.processInfo.environment["SEEDLING_DATA_DIR"],previousAppRunning:!NSRunningApplication.runningApplications(withBundleIdentifier:"app.ayra.torrent").isEmpty)
        } catch {
            resolved=base.appendingPathComponent("Seedling")
            migrationProblem=error.localizedDescription
        }
        root=resolved
        engine=TorrentEngine(directory:root.appendingPathComponent("Engine"))
        migrationBlocked=migrationProblem != nil
        error=migrationProblem
        if let data=try? Data(contentsOf:root.appendingPathComponent("preferences.json")),let saved=try? JSONDecoder().decode(Preferences.self,from:data) { preferences=saved }
    }
    func save() {
        do { try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);try JSONEncoder().encode(preferences).write(to:root.appendingPathComponent("preferences.json"),options:.atomic) } catch { self.error=error.localizedDescription }
    }
    func launch() async {
        guard !ready,!migrationBlocked else { return }
        do { try await engine.start();ready=true
            let queued=pendingURLs;pendingURLs=[];accept(queued)
            timer=Task { while !Task.isCancelled { await poll();try? await Task.sleep(nanoseconds:1_000_000_000) } }
        } catch { self.error=error.localizedDescription }
    }
    func shutdown() { timer?.cancel();engine.stop() }
    func poll() async {
        guard ready,!polling else { return };polling=true;defer {polling=false}
        do {
            let current=try await engine.transfers();transfers=current
            for t in current {
                guard t.error==0,t.metadataPercentComplete>=1 else {continue}
                if !routed.contains(t.hashString) {
                    let choice=preferences.destinations[t.hashString] ?? .automatic
                    let movie=choice == .movie || (choice == .automatic && t.movie)
                    let path=movie ? preferences.movieFolder : preferences.otherFolder
                    try await move(t,to:path);routed.insert(t.hashString)
                }
                if t.complete,!verified.contains(t.hashString),!verifying.contains(t.hashString) {
                    try await engine.callVoid("torrent-stop",["ids":[t.id]])
                    try await engine.callVoid("torrent-verify",["ids":[t.id]])
                    verifying.insert(t.hashString);verificationStarted[t.hashString]=Date()
                } else if verifying.contains(t.hashString),![1,2].contains(t.status),Date().timeIntervalSince(verificationStarted[t.hashString] ?? Date())>2 {
                    verifying.remove(t.hashString);verificationStarted[t.hashString]=nil
                    if t.complete { verified.insert(t.hashString);try await engine.callVoid("torrent-stop",["ids":[t.id]]) }
                    else { try await engine.callVoid("torrent-start",["ids":[t.id]]) }
                }
                if t.complete,verified.contains(t.hashString),preferences.removeCompleted {
                    try await remove(t)
                }
            }
        } catch { self.error=error.localizedDescription }
    }
    func move(_ t: Transfer,to path:String) async throws {
        guard t.downloadDir != path else {return}
        try FileManager.default.createDirectory(atPath:path,withIntermediateDirectories:true)
        try await engine.callVoid("torrent-set-location",["ids":[t.id],"location":path,"move":true])
    }
    func add(magnet:String? = nil,file:URL? = nil,choice:Destination = .automatic) async {
        guard ready else { error="The download engine is still starting.";return }
        do {
            let dir=choice == .movie ? preferences.movieFolder : preferences.otherFolder
            try FileManager.default.createDirectory(atPath:dir,withIntermediateDirectories:true)
            var args:[String:Any] = ["paused":false,"download-dir":dir]
            if let file { args["metainfo"]=try Data(contentsOf:file).base64EncodedString() }
            else if let magnet,let url=URLComponents(string:magnet.trimmingCharacters(in:.whitespacesAndNewlines)),url.scheme?.lowercased()=="magnet",url.queryItems?.contains(where:{$0.name=="xt" && ($0.value?.hasPrefix("urn:btih:")==true || $0.value?.hasPrefix("urn:btmh:")==true)})==true { args["filename"]=magnet.trimmingCharacters(in:.whitespacesAndNewlines) }
            else { throw EngineFailure(message:"Paste a valid magnet link, or choose a .torrent file.") }
            let result=try await engine.call("torrent-add",args)
            if result["torrent-duplicate"] != nil { throw EngineFailure(message:"This download is already in Seedling.") }
            if let added=result["torrent-added"] as? [String:Any],let hash=added["hashString"] as? String { preferences.destinations[hash]=choice;save() }
            showAdd=false;pendingMagnet="";await poll()
        } catch { self.error=error.localizedDescription }
    }
    func openFile(choice:Destination = .automatic) {
        let panel=NSOpenPanel();panel.allowedContentTypes=[UTType(filenameExtension:"torrent") ?? .data];panel.allowsMultipleSelection=true
        if panel.runModal() == .OK { let urls=panel.urls;Task {for url in urls {await add(file:url,choice:choice)}} }
    }
    func accept(_ urls:[URL]) { guard ready else {pendingURLs += urls;return};for url in urls { if url.scheme?.lowercased()=="magnet" { pendingMagnet=url.absoluteString;showAdd=true } else if url.pathExtension.lowercased()=="torrent" { Task {await add(file:url)} } } }
    func toggle(_ t:Transfer) { Task { do { try await engine.callVoid(t.status==0 ? "torrent-start":"torrent-stop",["ids":[t.id]]);await poll() } catch {self.error=error.localizedDescription} } }
    func remove(_ t:Transfer) async throws {
        // Removing a task must never remove the downloaded payload or the user’s source .torrent.
        try await engine.callVoid("torrent-remove",["ids":[t.id],"delete-local-data":false])
        preferences.destinations[t.hashString]=nil;save();transfers.removeAll{$0.hashString==t.hashString}
        routed.remove(t.hashString);verified.remove(t.hashString);verifying.remove(t.hashString)
    }
    func setDestination(_ t:Transfer,_ choice:Destination) { Task { do { let path=choice == .movie ? preferences.movieFolder:preferences.otherFolder;try await move(t,to:path);preferences.destinations[t.hashString]=choice;save();await poll() } catch {self.error=error.localizedDescription} } }
    func chooseFolder(movie:Bool) {
        let panel=NSOpenPanel();panel.canChooseFiles=false;panel.canChooseDirectories=true;panel.canCreateDirectories=true
        if panel.runModal() == .OK,let url=panel.url { if movie {preferences.movieFolder=url.path}else{preferences.otherFolder=url.path};save() }
    }
    func reveal(_ t:Transfer) { NSWorkspace.shared.selectFile(nil,inFileViewerRootedAtPath:t.downloadDir) }
}
extension TorrentEngine { func callVoid(_ method:String,_ args:[String:Any]) async throws {_ = try await call(method,args)} }
