import Foundation
import AppKit

@main struct ArtworkChecks {
    static func require(_ condition:Bool,_ message:String) {guard condition else {print("FAIL: "+message);exit(1)};print("PASS: "+message)}
    static func main() async throws {
        let identity=MovieIdentity.parse("Inception.2010.1080p.BluRay.x265-[ReleaseGroup].mkv")!
        require(identity.title=="Inception" && identity.year==2010,"clean title and year; release tags omitted")
        let chinese=MovieIdentity.parse("Wo De Lao Ban Wei He Na Yang (2026) [1080p] [WEBRip] [x265] [10bit] [5.1] [YTS.GG - YTS.BZ]")!
        require(chinese.title=="Wo De Lao Ban Wei He Na Yang" && chinese.year==2026,"current title cleaned without source-site information")
        require(MovieIdentity.parse("Show.S01E02.1080p.mkv")==nil,"TV episode rejected")
        require(MovieIdentity.parse(String(repeating:"a",count:40))==nil,"raw torrent hash rejected")
        require(MovieIdentity.parse("2001.A.Space.Odyssey.1968.1080p.mkv")?.title=="2001 A Space Odyssey","numeric movie title preserved")
        require(MovieIdentity.parse("The.Matrix.1080p.WEBRip.mp4")?.title=="The Matrix","technical tags removed without a year")
        require(MovieIdentity.parse("Blade.Runner.2049.1080p.mkv")?.title=="Blade Runner 2049","future number retained as part of the title")
        func response(_ pages:[[String:Any]]) throws -> ArtworkSearch {
            try JSONDecoder().decode(ArtworkSearch.self,from:JSONSerialization.data(withJSONObject:["query":["pages":pages]]))
        }
        let film:[String:Any]=["title":"Inception","fullurl":"https://en.wikipedia.org/wiki/Inception","pageimage":"Inception_poster.jpg","thumbnail":["source":"https://upload.wikimedia.org/wikipedia/en/test.jpg"],"terms":["description":["2010 film directed by Christopher Nolan"]]]
        let match=try response([film])
        require(match.match(identity) != nil,"exact title and release year matched")
        require(match.match(MovieIdentity(title:"Inception",year:2011))==nil,"wrong year rejected")
        var album=film;album["title"]="Inception (soundtrack)";album["terms"]=["description":["soundtrack album by Hans Zimmer for same-title film"]]
        require(try response([film,album]).match(identity) != nil,"soundtrack does not create a false movie match")
        var remake=film;remake["title"]="Inception (2020 film)";remake["terms"]=["description":["2020 film"]]
        require(try response([film,remake]).match(MovieIdentity(title:"Inception",year:nil))==nil,"ambiguous remake titles keep the fallback icon")
        var unsafe=film;unsafe["thumbnail"]=["source":"https://example.com/untrusted.jpg"]
        require(try response([unsafe]).match(identity)==nil,"non-Wikimedia image URL rejected")
        let cache=URL(fileURLWithPath:CommandLine.arguments[1])
        let service=MovieArtworkService(directory:cache)
        guard let art=await service.load(identity),let image=NSImage(data:art.imageData) else {print("FAIL: live Wikipedia poster lookup");exit(1)}
        require(image.size.width>0 && image.size.height>0,"live poster downloaded and decoded")
        require(art.pageURL.host=="en.wikipedia.org" && art.creditsURL.absoluteString.contains("File"),"source and artwork credits available")
        let files=try FileManager.default.contentsOfDirectory(at:cache,includingPropertiesForKeys:nil)
        require(files.count==1,"poster cached once")
        let second=MovieArtworkService(directory:cache)
        let cached=await second.load(identity)
        require(cached?.imageData==art.imageData,"cached artwork survives service restart")
        try art.imageData.write(to:cache.appendingPathComponent("inception-poster.jpg"))
        if CommandLine.arguments.contains("--current-title") {
            let current=await service.load(chinese)
            print(current==nil ? "CURRENT TITLE: no confident match; film icon retained":"CURRENT TITLE: artwork found")
        }
        print("ALL ARTWORK CHECKS PASSED")
    }
}
