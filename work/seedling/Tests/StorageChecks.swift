import Foundation

@main struct StorageChecks {
    static func require(_ condition:Bool,_ message:String) {
        guard condition else {print("FAIL: "+message);exit(1)}
        print("PASS: "+message)
    }
    static func main() throws {
        let fm=FileManager.default
        let base=URL(fileURLWithPath:CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at:base,withIntermediateDirectories:true)
        defer {try? fm.removeItem(at:base)}
        let previous=base.appendingPathComponent("Ayra")
        let nested=["preferences.json","Engine/Resume/test.resume","Engine/Torrents/test.torrent","Artwork/poster.json"]
        for path in nested {
            let url=previous.appendingPathComponent(path)
            try fm.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
            try Data(("preserved:"+path).utf8).write(to:url)
        }
        do {_ = try SeedlingStorage.resolve(base:base,previousAppRunning:true);require(false,"migration refused while previous app runs")}
        catch {require(fm.fileExists(atPath:previous.path),"running previous app blocks migration without changing data")}
        let destination=try SeedlingStorage.resolve(base:base)
        require(destination.lastPathComponent=="Seedling","new app data uses Seedling name")
        require(!fm.fileExists(atPath:previous.path),"entire old directory renamed together")
        for path in nested {
            require(try Data(contentsOf:destination.appendingPathComponent(path))==Data(("preserved:"+path).utf8),"preserved "+path)
        }
        require(try SeedlingStorage.resolve(base:base)==destination,"migration is safe to retry")
        try fm.createDirectory(at:previous,withIntermediateDirectories:true)
        try Data("old".utf8).write(to:previous.appendingPathComponent("legacy-state"))
        _ = try SeedlingStorage.resolve(base:base)
        require(fm.fileExists(atPath:previous.appendingPathComponent("legacy-state").path),"existing new data never overwritten or merged")
        let override=base.appendingPathComponent("isolated").path
        require(try SeedlingStorage.resolve(base:base,override:override).path==override,"test override stays isolated")
        let fresh=base.appendingPathComponent("fresh")
        require(try SeedlingStorage.resolve(base:fresh).lastPathComponent=="Seedling","fresh install uses new name")
        print("ALL STORAGE CHECKS PASSED")
    }
}
