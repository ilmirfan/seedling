import Foundation

@main struct Checks {
    @MainActor static var activeEngine:TorrentEngine?
    @MainActor static func main() async throws {
        let store=SeedlingStore()
        store.preferences.movieFolder=store.root.appendingPathComponent("Movies").path
        store.preferences.otherFolder=store.root.appendingPathComponent("Other").path
        store.preferences.removeCompleted=false
        try await store.engine.start();activeEngine=store.engine;store.ready=true
        defer {store.engine.stop()}
        let session=try await store.engine.call("session-get")
        require(session["speed-limit-up-enabled"] as? Bool == true && session["speed-limit-up"] as? Int == 20,"upload capped at 20 KB/s")
        require(session["seedRatioLimit"] as? Double == 0 && session["seedRatioLimited"] as? Bool == true,"no extended seeding after completion")
        let fixture=store.root.appendingPathComponent("fixtures")
        let paths=try FileManager.default.contentsOfDirectory(at:fixture,includingPropertiesForKeys:nil).filter{$0.pathExtension=="torrent"}
        require(paths.count==2,"two test torrents exist")
        for p in paths {await store.add(file:p)}
        require(store.error==nil,"torrent files accepted: \(store.error ?? "")")
        for _ in 0..<100 { await store.poll();if store.transfers.count==2 && store.transfers.allSatisfy({store.verified.contains($0.hashString)}) {break};try await Task.sleep(nanoseconds:300_000_000) }
        let list=store.transfers
        print("Transfer diagnostics:",list.map{ "\($0.name): status \($0.status) valid \($0.haveValid)/\($0.totalSize) error \($0.errorString)" }, "Store error:",store.error ?? "none")
        require(list.count==2,"two transfers retained")
        require(list.allSatisfy(\.complete),"100% payload and all pieces valid")
        require(list.allSatisfy{store.verified.contains($0.hashString)},"full recheck completed")
        require(list.first{$0.movie}?.downloadDir==store.preferences.movieFolder,"movie routed to Movies")
        require(list.first{!$0.movie}?.downloadDir==store.preferences.otherFolder,"non-movie routed to Other")
        let files=list.map{URL(fileURLWithPath:$0.downloadDir).appendingPathComponent($0.name)}
        for p in files {require(FileManager.default.fileExists(atPath:p.path),"download exists")}
        // Re-add a retained transfer’s magnet URI: exercise real engine duplicate recognition.
        if let first=list.first {await store.add(magnet:"magnet:?xt=urn:btih:\(first.hashString)");require(store.error=="This download is already in Seedling.","magnet accepted and duplicate detected");store.error=nil}
        await store.add(magnet:"https://example.com/not-a-magnet")
        require(store.error != nil,"invalid magnet rejected");store.error=nil
        store.preferences.removeCompleted=true
        await store.poll()
        require(store.transfers.isEmpty,"auto-remove clears only completed entries")
        for p in files {require(FileManager.default.fileExists(atPath:p.path),"auto-remove preserves payload")}
        for p in paths {require(FileManager.default.fileExists(atPath:p.path),"original torrent preserved")}
        let f=TorrentFile(name:"Show.S01E01.mkv",length:42,bytesCompleted:42)
        require(!MovieClassifier.isMovie(name:f.name,files:[f]),"TV episodes excluded from movie heuristic")
        let m=TorrentFile(name:"Film.mkv",length:42,bytesCompleted:42)
        require(MovieClassifier.isMovie(name:m.name,files:[m]),"single movie detected")
        if var t=list.first {t.haveValid=0;require(!t.complete,"unverified bytes block completion");t=list[0];t.files[0].bytesCompleted=0;require(!t.complete,"incomplete file blocks completion");t=list[0];t.status=2;require(!t.complete,"active recheck blocks removal");t=list[0];t.metadataPercentComplete=0;require(!t.complete,"missing metadata blocks completion")}
        let added=try await store.engine.call("torrent-add",["filename":"magnet:?xt=urn:btih:1111111111111111111111111111111111111111","paused":true,"download-dir":store.preferences.otherFolder])
        require(added["torrent-added"] != nil,"fresh magnet task accepted")
        var pending=try await store.engine.transfers()
        require(pending.count==1 && pending[0].status==0,"magnet starts paused when requested")
        let pendingID=pending[0].id
        try await store.engine.callVoid("torrent-start",["ids":[pendingID]])
        try await Task.sleep(nanoseconds:300_000_000)
        pending=try await store.engine.transfers()
        require(pending[0].status != 0,"resume starts task")
        try await store.engine.callVoid("torrent-stop",["ids":[pendingID]])
        try await Task.sleep(nanoseconds:300_000_000)
        pending=try await store.engine.transfers()
        require(pending[0].status==0,"pause stops task")
        await store.poll();require(store.transfers.count==1,"incomplete magnet is never auto-removed")
        try await store.remove(pending[0])
        print("ALL CHECKS PASSED")
    }
    @MainActor static func require(_ condition:Bool,_ message:String) {if !condition {print("FAIL: "+message);activeEngine?.stop();exit(1)};print("PASS: "+message)}
}
