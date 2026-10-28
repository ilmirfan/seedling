import SwiftUI
import AppKit
import CryptoKit

struct MovieIdentity: Hashable {
    let title: String
    let year: Int?
    var key: String { Self.normalized(title) + "|" + (year.map(String.init) ?? "") }
    static func normalized(_ text: String) -> String {
        text.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:Locale(identifier:"en_US_POSIX"))
            .components(separatedBy:CharacterSet.alphanumerics.inverted).filter{!$0.isEmpty}.joined(separator:" ")
    }
    static func parse(_ filename: String) -> MovieIdentity? {
        var text=filename.replacingOccurrences(of:#"(?i)\.(torrent|mkv|mp4|avi|mov|m4v|webm|mpg|mpeg|m2ts)$"#,with:"",options:.regularExpression)
        guard text.range(of:#"(?i)\b(s\d{1,2}e\d{1,3}|\d{1,2}x\d{2}|season[ ._-]*\d+)\b"#,options:.regularExpression)==nil else {return nil}
        // Remove source/site tags before extracting the release year; keep bracketed years.
        text=text.replacingOccurrences(of:#"\[(?!\d{4}\])[^\]]*\]"#,with:" ",options:.regularExpression)
        let ns=text as NSString
        let expression=try! NSRegularExpression(pattern:#"(?<!\d)(?:19|20)\d{2}(?!\d)"#)
        let latestYear=Calendar.current.component(.year,from:Date())+1
        let years=expression.matches(in:text,range:NSRange(location:0,length:ns.length)).filter{$0.range.location>0 && (Int(ns.substring(with:$0.range)) ?? Int.max)<=latestYear}
        var year:Int?
        if let found=years.last {year=Int(ns.substring(with:found.range));text=ns.substring(to:found.range.location)}
        if let technical=text.range(of:#"(?i)(?:^|[ ._-])(?:2160p|1080p|1080i|720p|480p|4k|bluray|blu-ray|brrip|bdrip|webrip|web-dl|webdl|dvdrip|hdtv|remux|x264|x265|h264|h265|hevc|hdr|aac)\b"#,options:.regularExpression) {text=String(text[..<technical.lowerBound])}
        text=text.replacingOccurrences(of:#"[._]+"#,with:" ",options:.regularExpression)
            .replacingOccurrences(of:#"[\[\]()]+"#,with:" ",options:.regularExpression)
            .replacingOccurrences(of:#"\s+"#,with:" ",options:.regularExpression)
            .trimmingCharacters(in:CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn:"-")))
        guard !text.isEmpty,text.count<=160,text.range(of:#"^[a-fA-F0-9]{32,64}$"#,options:.regularExpression)==nil else {return nil}
        return MovieIdentity(title:text,year:year)
    }
}

struct ArtworkSearch: Decodable {
    var query: Query?
    struct Query: Decodable {var pages:[Page]}
    struct Page: Decodable {
        var title:String
        var fullurl:URL?
        var pageimage:String?
        var thumbnail:Thumbnail?
        var terms:Terms?
        struct Thumbnail:Decodable {var source:URL}
        struct Terms:Decodable {var description:[String]?}
    }
    func match(_ movie:MovieIdentity) -> Page? {
        let matches=(query?.pages ?? []).filter {page in
            let title=page.title.replacingOccurrences(of:#"\s*\([^)]*\)$"#,with:"",options:.regularExpression)
            guard MovieIdentity.normalized(title)==MovieIdentity.normalized(movie.title),let description=page.terms?.description?.first?.lowercased(),let releaseYear=Int(description.prefix(4)),description.range(of:#"\b(film|movie)\b"#,options:.regularExpression) != nil else {return false}
            // Exclude similarly named albums, series and other related subjects.
            guard !["album","soundtrack","television series","video game","novel","franchise"].contains(where:description.contains) else {return false}
            if page.title.contains("("),page.title.range(of:#"(?i)\([^)]*\bfilm\)$"#,options:.regularExpression)==nil {return false}
            if let year=movie.year,releaseYear != year {return false}
            guard let image=page.thumbnail?.source,image.scheme=="https",["upload.wikimedia.org","thumb.wikimedia.org"].contains(image.host ?? ""),page.fullurl?.host=="en.wikipedia.org",page.pageimage != nil else {return false}
            return true
        }
        return matches.count==1 ? matches.first:nil
    }
}

struct MovieArtwork: Codable {
    let title:String
    let pageURL:URL
    let creditsURL:URL
    let imageData:Data
    let savedAt:Date
}

actor MovieArtworkService {
    static let shared=MovieArtworkService()
    private let session=URLSession(configuration:.ephemeral)
    private let cacheDirectory:URL
    private var hits:[String:MovieArtwork]=[:]
    private var misses:[String:Date]=[:]
    private var pending:[String:Task<MovieArtwork?,Never>]=[:]
    private var nextRequest=Date.distantPast
    init(directory:URL? = nil) {
        cacheDirectory=directory ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Seedling/Artwork")
    }
    func load(_ movie:MovieIdentity) async -> MovieArtwork? {
        let key=movie.key
        if let hit=hits[key] {return hit}
        if let miss=misses[key],Date().timeIntervalSince(miss)<600 {return nil}
        let file=cacheDirectory.appendingPathComponent(SHA256.hash(data:Data(key.utf8)).map{String(format:"%02x",$0)}.joined()+".json")
        if let data=try? Data(contentsOf:file),let hit=try? JSONDecoder().decode(MovieArtwork.self,from:data),Date().timeIntervalSince(hit.savedAt)<7*24*60*60,hits.count<100 {
            hits[key]=hit;return hit
        }
        if let task=pending[key] {return await task.value}
        let task=Task {await fetch(movie)};pending[key]=task
        let result=await task.value;pending[key]=nil
        if let result {
            if hits.count>=100 {hits.removeAll()}
            hits[key]=result
            try? FileManager.default.createDirectory(at:cacheDirectory,withIntermediateDirectories:true)
            if let data=try? JSONEncoder().encode(result) {try? data.write(to:file,options:.atomic)}
        } else {misses[key]=Date()}
        return result
    }
    private func fetch(_ movie:MovieIdentity) async -> MovieArtwork? {
        // At most one new metadata request per second; downloading is independent.
        let now=Date();let delay=max(0,nextRequest.timeIntervalSince(now));nextRequest=max(now,nextRequest).addingTimeInterval(1)
        if delay>0 {try? await Task.sleep(nanoseconds:UInt64(delay*1_000_000_000))}
        var components=URLComponents(string:"https://en.wikipedia.org/w/api.php")!
        let query=movie.title+(movie.year.map{" \($0)"} ?? "")+" film"
        let params=["action":"query","format":"json","formatversion":"2","generator":"search","gsrsearch":query,"gsrlimit":"8","gsrnamespace":"0","prop":"pageimages|pageterms|info","wbptterms":"description","piprop":"thumbnail|name","pithumbsize":"160","pilicense":"any","inprop":"url"]
        components.queryItems=params.sorted{$0.key<$1.key}.map{URLQueryItem(name:$0.key,value:$0.value)}
        guard let url=components.url else {return nil}
        do {
            var request=URLRequest(url:url);request.timeoutInterval=12
            request.setValue("Seedling/0.1 (macOS; movie artwork lookup)",forHTTPHeaderField:"User-Agent")
            let (data,response)=try await session.data(for:request)
            guard (response as? HTTPURLResponse)?.statusCode==200,data.count<2_000_000,let search=try? JSONDecoder().decode(ArtworkSearch.self,from:data),let match=search.match(movie),let thumbnail=match.thumbnail?.source,let page=match.fullurl,let file=match.pageimage else {return nil}
            var imageRequest=URLRequest(url:thumbnail);imageRequest.timeoutInterval=12
            imageRequest.setValue("Seedling/0.1 (macOS; movie artwork lookup)",forHTTPHeaderField:"User-Agent")
            let (bytes,imageResponse)=try await session.data(for:imageRequest)
            guard let http=imageResponse as? HTTPURLResponse,http.statusCode==200,http.mimeType?.hasPrefix("image/")==true,!bytes.isEmpty,bytes.count<2_000_000 else {return nil}
            var credits=URLComponents(string:"https://en.wikipedia.org/w/index.php")!
            credits.queryItems=[URLQueryItem(name:"title",value:"File:"+file)]
            guard let creditsURL=credits.url else {return nil}
            return MovieArtwork(title:match.title,pageURL:page,creditsURL:creditsURL,imageData:bytes,savedAt:Date())
        } catch {return nil}
    }
}

@MainActor final class MovieArtworkModel:ObservableObject {
    @Published var artwork:MovieArtwork?
    @Published var image:NSImage?
    func load(_ movie:MovieIdentity?) async {
        artwork=nil;image=nil
        guard let movie,let result=await MovieArtworkService.shared.load(movie),!Task.isCancelled,let decoded=NSImage(data:result.imageData) else {return}
        artwork=result;image=decoded
    }
}

struct TransferArtwork:View {
    let name:String
    let movie:Bool
    let accent:Color
    @StateObject private var model=MovieArtworkModel()
    @Environment(\.openURL) private var openURL
    private var identity:MovieIdentity? {movie ? MovieIdentity.parse(name):nil}
    var body:some View {
        Group {
            if let image=model.image {
                Image(nsImage:image).resizable().scaledToFill()
                    .accessibilityLabel("Movie artwork for \(model.artwork?.title ?? name)")
            } else {
                Image(systemName:movie ? "film":"arrow.down.doc").font(.system(size:23,weight:.light)).foregroundStyle(accent)
            }
        }
        .frame(width:52,height:58).background(accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius:12))
        .help(model.artwork == nil ? (movie ? "Movie artwork unavailable":"Download") : "Movie artwork from Wikipedia. Right-click for source and credits.")
        .contextMenu {
            if let artwork=model.artwork {
                Button("Movie on Wikipedia") {openURL(artwork.pageURL)}
                Button("Artwork source & credits") {openURL(artwork.creditsURL)}
            }
        }
        .task(id:identity) {await model.load(identity)}
    }
}
