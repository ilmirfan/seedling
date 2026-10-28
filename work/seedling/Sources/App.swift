import SwiftUI
import AppKit
import UniformTypeIdentifiers

let seedGreen = Color(red:35.0/255,green:131.0/255,blue:75.0/255)
let coral = Color(red:0.97,green:0.43,blue:0.35)
let mint = Color(red:0.13,green:0.66,blue:0.53)
let ink = Color(red:25.0/255,green:51.0/255,blue:38.0/255)
let resumeGreen = seedGreen

@main struct SeedlingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = SeedlingStore()
    var body: some Scene {
        WindowGroup("Seedling") {
            ContentView().environmentObject(store)
                .task { delegate.store=store;await store.launch();store.accept(delegate.pendingURLs);delegate.pendingURLs=[] }
                .onOpenURL { store.accept([$0]) }
                .onReceive(NotificationCenter.default.publisher(for:.seedlingOpen)) { note in if let urls=note.object as? [URL] {store.accept(urls)} }
        }
        .windowStyle(.hiddenTitleBar).defaultSize(width:860,height:670)
        .commands {
            CommandGroup(replacing:.newItem) {
                Button("Add Magnet Link…") {store.showAdd=true}.keyboardShortcut("n")
                Button("Open Torrent File…") {store.openFile()}.keyboardShortcut("o")
            }
        }
        Settings { SettingsView().environmentObject(store).preferredColorScheme(.light) }
    }
}
extension Notification.Name { static let seedlingOpen=Notification.Name("SeedlingOpen") }
@MainActor final class AppDelegate: NSObject,NSApplicationDelegate {
    weak var store:SeedlingStore?
    var pendingURLs:[URL]=[]
    func applicationDidFinishLaunching(_ notification: Notification) { NSApp.setActivationPolicy(.regular);NSApp.activate(ignoringOtherApps:true) }
    func application(_ application:NSApplication,open urls:[URL]) { if let store,store.ready {store.accept(urls)} else {pendingURLs += urls} }
    func applicationWillTerminate(_ notification:Notification) { store?.shutdown() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { false }
}
struct ContentView: View {
    @EnvironmentObject var store:SeedlingStore
    var totalRate:Int64 {store.transfers.reduce(0){$0+$1.rateDownload}}
    var body:some View {
        VStack(spacing:0) {
            HStack(alignment:.center) {
                HStack(spacing:10) {
                    if let url=Bundle.main.url(forResource:"Seedling-header",withExtension:"png"),let image=NSImage(contentsOf:url) {
                        Image(nsImage:image).resizable().interpolation(.high).scaledToFit()
                            .frame(width:50,height:50).accessibilityHidden(true)
                    }
                    Text("Seedling").font(.custom("Futura-Medium",size:40)).tracking(-1.5)
                }
                Spacer()
                headerControls
            }.padding(.horizontal,32).padding(.top,30).padding(.bottom,26)
            if !store.transfers.isEmpty {
                HStack(alignment:.bottom) {
                    Text("YOUR DOWNLOADS").font(.system(size:10,weight:.bold)).tracking(1.7).foregroundStyle(seedGreen)
                    Spacer()
                    VStack(alignment:.trailing,spacing:4) {
                        Text("↓ "+byteString(totalRate)+"/s").font(.system(size:17,weight:.semibold,design:.rounded))
                        Text("\(store.transfers.count) in your list").font(.system(size:11)).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal,32).padding(.bottom,22)
            }
            if !store.ready { ProgressView("Getting ready…").frame(maxWidth:.infinity,maxHeight:.infinity) }
            else if store.transfers.isEmpty { Spacer(minLength:0) }
            else { ScrollView {LazyVStack(spacing:12) {ForEach(store.transfers) {t in TransferCard(transfer:t)}}.padding(.horizontal,30).padding(.bottom,20)} }
            HStack {
                Spacer()
                SettingsLink {
                    Image(systemName:"slider.horizontal.3")
                        .font(.system(size:17)).foregroundStyle(ink)
                        .frame(width:32,height:32).contentShape(Rectangle())
                }.buttonStyle(.plain).help("Settings")
            }.padding(.horizontal,28).padding(.top,8).padding(.bottom,20)
        }
        .foregroundStyle(ink).background(Color(red:243.0/255,green:248.0/255,blue:244.0/255))
        .frame(minWidth:680,minHeight:550).preferredColorScheme(.light)
        .overlay {if store.ready && store.transfers.isEmpty {empty.ignoresSafeArea()}}
        .sheet(isPresented:$store.showAdd) { AddView().environmentObject(store) }
        .alert("Something needs attention",isPresented:Binding(get:{store.error != nil},set:{if !$0 {store.error=nil}})) {Button("OK"){store.error=nil}} message:{Text(store.error ?? "")}
        .onDrop(of:[UTType.fileURL.identifier,UTType.url.identifier,UTType.text.identifier],isTargeted:$store.isDropping) {providers in
            for p in providers {
                if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) { _ = p.loadObject(ofClass:URL.self) {url,_ in if let url {Task {@MainActor in store.accept([url])}}} }
                else { _ = p.loadObject(ofClass:String.self) {value,_ in if let value,let url=URL(string:value.trimmingCharacters(in:.whitespacesAndNewlines)),url.scheme=="magnet" {Task {@MainActor in store.accept([url])}}} }
            };return !providers.isEmpty
        }
        .overlay {if store.isDropping {RoundedRectangle(cornerRadius:18).stroke(seedGreen,style:StrokeStyle(lineWidth:3,dash:[9])).padding(10).allowsHitTesting(false)}}
    }
    private var headerControls:some View {
        HStack(spacing:12) {
            Button {store.showAdd=true} label:{Label("Add download",systemImage:"plus").font(.system(size:12,weight:.semibold)).padding(.horizontal,6).padding(.vertical,2)}
                .seedlingButton(prominent:true).keyboardShortcut("n")
        }
    }
    var empty:some View {
        GeometryReader { geometry in
            ZStack {
                EmptyDownloadArtwork()
                    .position(x:geometry.size.width/2,y:geometry.size.height/2)
                Button("Choose a torrent file") {store.openFile()}
                    .buttonStyle(.plain).font(.system(size:12,weight:.semibold)).foregroundStyle(seedGreen)
                    .position(x:geometry.size.width/2,y:geometry.size.height/2 + 118)
            }
        }
    }
}
struct TransferCard:View {
    @EnvironmentObject var store:SeedlingStore
    let transfer:Transfer
    var t:Transfer {transfer}
    var checking:Bool {store.verifying.contains(t.hashString) || [1,2].contains(t.status)}
    var finished:Bool {t.complete && store.verified.contains(t.hashString)}
    var movie:Bool {let d=store.preferences.destinations[t.hashString] ?? .automatic;return d == .movie || (d == .automatic && t.movie)}
    var paused:Bool {t.status==0 && !finished && !checking}
    var accent:Color {finished ? mint : t.status==0 && !checking ? Color.gray : movie ? coral:seedGreen}
    var state:String {if t.error != 0 {return t.errorString};if checking {return "Checking every piece…"};if finished {return "Complete · saved safely"};if t.metadataPercentComplete<1 {return "Finding download details…"};if t.status==0 {return "Paused"};if t.rateDownload==0 {return "Connecting to peers…"};return byteString(t.rateDownload)+"/s"+(t.eta>0 ? " · "+eta(t.eta)+" left":"")}
    var body:some View {
        HStack(alignment:.top,spacing:16) {
            TransferArtwork(name:t.name,movie:movie,accent:accent)
            VStack(alignment:.leading,spacing:10) {
                HStack {Text(t.name).font(.system(size:14,weight:.semibold)).lineLimit(1).help(t.name);Spacer();Text(finished ? "100%": "\(Int(min(1,max(0,t.percentDone))*100))%").font(.system(size:12,weight:.semibold,design:.rounded)).foregroundStyle(accent)}
                GeometryReader {g in ZStack(alignment:.leading) {Capsule().fill(accent.opacity(0.1));Capsule().fill(LinearGradient(colors:[accent.opacity(0.65),accent],startPoint:.leading,endPoint:.trailing)).frame(width:max(0,g.size.width * min(1,max(0,checking ? t.recheckProgress:t.percentDone))))}}.frame(height:7)
                HStack {Text(state).foregroundStyle(t.error != 0 ? coral:Color.secondary).lineLimit(1);Spacer();Text(byteString(t.totalSize)).foregroundStyle(.secondary)}.font(.system(size:10))
                HStack(spacing:5) {Image(systemName:movie ? "film":"folder");Text(movie ? "Movies":"Other downloads");Text("·");Text("\(t.seeds) seeds · \(t.leeches) peers").help("Connected seeds and peers; tracker totals may differ.")}.font(.system(size:9)).foregroundStyle(.secondary)
            }
            Button {if finished {store.reveal(t)}else{store.toggle(t)}} label:{Group {if paused {Image(systemName:"play.fill").foregroundStyle(.white)}else{Image(systemName:finished ? "folder":t.status==0 ? "play.fill":"pause.fill")}}.font(.system(size:12)).frame(width:23,height:23)}.seedlingPlaybackButton(paused:paused).tint(accent).disabled(checking).help(finished ? "Show downloaded files":t.status==0 ? "Resume":"Pause")
        }.padding(20).background(.white,in:RoundedRectangle(cornerRadius:19)).overlay(RoundedRectangle(cornerRadius:19).stroke(.black.opacity(0.025))).contextMenu {
            Button("Show in Finder") {store.reveal(t)}
            Button("Save to Movies") {store.setDestination(t,.movie)}
            Button("Save to Other Folder") {store.setDestination(t,.other)}
            Divider()
            Button("Remove from List") {Task {do {try await store.remove(t)}catch{store.error=error.localizedDescription}}}
        }
    }
    func eta(_ seconds:Int)->String {seconds>=3600 ? "\(seconds/3600)h \((seconds%3600)/60)m":seconds>=60 ? "\(seconds/60)m":"\(seconds)s"}
}
@MainActor final class AddFormModel:ObservableObject { @Published var destination:Destination = .automatic; @Published var adding=false }
struct AddView:View {
    @EnvironmentObject var store:SeedlingStore
    @Environment(\.dismiss) var dismiss
    @StateObject private var form=AddFormModel()
    var body:some View {
        VStack(alignment:.leading,spacing:20) {
            Text("Add download").font(.system(size:25,weight:.semibold,design:.rounded))
            TextField("magnet:?xt=…",text:$store.pendingMagnet).textFieldStyle(.roundedBorder).onSubmit {add()}
            Picker("Save as",selection:$form.destination) {ForEach(Destination.allCases,id:\.self) {Text($0.rawValue).tag($0)}}.pickerStyle(.segmented)
            Text("Automatic detects likely movies from filenames. TV episodes and other files use your other folder. You can change the destination later.").font(.system(size:11)).foregroundStyle(.secondary)
            HStack {Button("Choose .torrent…") {store.openFile(choice:form.destination)}.seedlingButton();Spacer();Button("Cancel"){dismiss()}.seedlingButton().keyboardShortcut(.cancelAction);Button(form.adding ? "Adding…":"Add download"){add()}.seedlingButton(prominent:true).disabled(store.pendingMagnet.isEmpty || form.adding)}
        }.padding(30).frame(width:500)
    }
    func add() {guard !form.adding else {return};form.adding=true;Task {await store.add(magnet:store.pendingMagnet,choice:form.destination);form.adding=false}}
}
struct SettingsView:View {
    @EnvironmentObject var store:SeedlingStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var defaultClient = DefaultTorrentClient()
    var body:some View {
        VStack(alignment:.leading,spacing:25) {
            Text("Settings").font(.system(size:23,weight:.semibold,design:.rounded))
            VStack(alignment:.leading,spacing:8) {
                HStack {
                    Text("Default torrent client").font(.system(size:12,weight:.semibold))
                    Spacer()
                    Button(defaultClient.updating ? "Updating…" : defaultClient.isDefault ? "Default" : "Make Default…") {
                        Task { await defaultClient.makeDefault() }
                    }.seedlingButton().disabled(defaultClient.updating || defaultClient.isDefault)
                }
                Text("Magnet links: " + (defaultClient.handlesMagnets ? "Seedling" : "Another app") + " · Torrent files: " + (defaultClient.handlesTorrentFiles ? "Seedling" : "Another app"))
                    .font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                Text("Open magnet links and .torrent files with Seedling. Confirm the change if macOS asks.")
                    .font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }
            Divider()
            folder("Movies",path:store.preferences.movieFolder,movie:true)
            folder("Everything else",path:store.preferences.otherFolder,movie:false)
            Divider()
            Toggle("Remove completed downloads from the list",isOn:$store.preferences.removeCompleted).onChange(of:store.preferences.removeCompleted) {_,_ in store.save()}
            Text("Only after a full file check. Your downloaded files stay safe.").font(.system(size:11)).foregroundStyle(.secondary)
            Divider()
            Text("Uploads stay light: capped at 20 KB/s while downloading. Completed downloads stop sharing.").font(.system(size:11)).foregroundStyle(.secondary)
        }.padding(30).frame(width:490).tint(seedGreen)
        .onAppear { defaultClient.refresh() }
        .onChange(of:scenePhase) { _,phase in if phase == .active { defaultClient.refresh() } }
        .alert("Default app change incomplete",isPresented:Binding(get:{defaultClient.error != nil},set:{if !$0 {defaultClient.error=nil}})) {
            Button("OK") { defaultClient.error=nil }
        } message: { Text(defaultClient.error ?? "") }
    }
    func folder(_ title:String,path:String,movie:Bool)->some View {HStack {VStack(alignment:.leading,spacing:5) {Text(title).font(.system(size:12,weight:.semibold));Text(path.replacingOccurrences(of:FileManager.default.homeDirectoryForCurrentUser.path,with:"~")).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).help(path)};Spacer();Button("Choose…"){store.chooseFolder(movie:movie)}.seedlingButton()}}
}
