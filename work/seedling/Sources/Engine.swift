import Foundation

struct EngineFailure: LocalizedError { let message: String; var errorDescription: String? { message } }
@MainActor final class TorrentEngine {
    private var process: Process?
    private let session = URLSession(configuration:.ephemeral)
    private var token = ""
    private var password = UUID().uuidString
    private var port = Int.random(in: 49152...65000)
    let directory: URL
    init(directory: URL) { self.directory = directory }
    func start() async throws {
        guard process == nil else { return }
        guard let executable = Bundle.main.url(forAuxiliaryExecutable:"transmission-daemon") else { throw EngineFailure(message:"Seedling’s download engine is missing. Rebuild the app with build.sh.") }
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let settings: [String:Any] = ["rpc-enabled":true,"rpc-bind-address":"127.0.0.1","rpc-port":port,"rpc-authentication-required":true,"rpc-username":"seedling","rpc-password":password,"rpc-whitelist-enabled":true,"rpc-whitelist":"127.0.0.1","rpc-host-whitelist-enabled":true,"rpc-host-whitelist":"localhost","speed-limit-up-enabled":true,"speed-limit-up":20,"ratio-limit-enabled":true,"ratio-limit":0,"download-dir":directory.appendingPathComponent("Incoming").path,"incomplete-dir-enabled":false,"trash-original-torrent-files":false,"port-forwarding-enabled":false,"peer-port":Int.random(in:49152...65000)]
        // Preserve the engine’s resume state, but choose fresh local credentials each launch.
        let config = directory.appendingPathComponent("settings.json")
        var existing = (try? JSONSerialization.jsonObject(with:Data(contentsOf:config))) as? [String:Any] ?? [:]
        existing.merge(settings) { _,new in new }
        try JSONSerialization.data(withJSONObject:existing,options:.sortedKeys).write(to:config,options:.atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:config.path)
        let p = Process(); p.executableURL=executable; p.arguments=["--foreground","--config-dir",directory.path]
        p.standardOutput=FileHandle.nullDevice; p.standardError=FileHandle.nullDevice
        try p.run(); process=p
        for _ in 0..<80 {
            do { _ = try await call("session-get"); return } catch { try await Task.sleep(nanoseconds:100_000_000) }
            if !p.isRunning { process=nil; throw EngineFailure(message:"The download engine could not start. Try reopening Seedling.") }
        }
        stop(); throw EngineFailure(message:"The download engine took too long to start.")
    }
    func stop() { if let p=process,p.isRunning { p.terminate(); p.waitUntilExit() }; process=nil }
    func call(_ method: String,_ arguments: [String:Any] = [:]) async throws -> [String:Any] {
        for attempt in 0..<3 {
            var req=URLRequest(url:URL(string:"http://127.0.0.1:\(port)/transmission/rpc")!);req.httpMethod="POST";req.timeoutInterval=8
            req.setValue("application/json",forHTTPHeaderField:"Content-Type")
            req.setValue("Basic "+Data("seedling:\(password)".utf8).base64EncodedString(),forHTTPHeaderField:"Authorization")
            req.setValue(token,forHTTPHeaderField:"X-Transmission-Session-Id")
            req.httpBody=try JSONSerialization.data(withJSONObject:["method":method,"arguments":arguments])
            let (data,response)=try await session.data(for:req)
            guard let http=response as? HTTPURLResponse else { throw EngineFailure(message:"No response from download engine.") }
            if http.statusCode==409,attempt<2 { token=http.value(forHTTPHeaderField:"X-Transmission-Session-Id") ?? "";continue }
            guard http.statusCode==200,let json=try JSONSerialization.jsonObject(with:data) as? [String:Any] else { throw EngineFailure(message:"Download engine returned an invalid response.") }
            guard json["result"] as? String == "success" else { throw EngineFailure(message:json["result"] as? String ?? "Download engine request failed.") }
            return json["arguments"] as? [String:Any] ?? [:]
        }
        throw EngineFailure(message:"Could not authenticate with the download engine.")
    }
    func transfers() async throws -> [Transfer] {
        let args=try await call("torrent-get",["fields":Transfer.fields])
        let data=try JSONSerialization.data(withJSONObject:args["torrents"] ?? [])
        return try JSONDecoder().decode([Transfer].self,from:data)
    }
}
