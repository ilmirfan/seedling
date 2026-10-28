import SwiftUI
import AppKit

@main struct ArtworkPreview:App {
    @NSApplicationDelegateAdaptor(PreviewDelegate.self) var delegate
    var body:some Scene {
        WindowGroup("Seedling — Artwork Preview") {
            VStack(alignment:.leading,spacing:20) {
                HStack(alignment:.firstTextBaseline) {
                    Text("Seedling").font(.custom("Futura-Medium",size:34)).tracking(-1.3)
                    Spacer()
                    Text("ARTWORK PREVIEW").font(.system(size:9,weight:.semibold)).tracking(1.2).foregroundStyle(.secondary)
                }
                HStack(spacing:16) {
                    TransferArtwork(name:"Inception.2010.1080p.BluRay.mkv",movie:true,accent:.orange)
                    VStack(alignment:.leading,spacing:7) {
                        Text("Inception (2010)").font(.system(size:14,weight:.semibold))
                        Text("Sample title · live Wikipedia artwork").font(.system(size:11)).foregroundStyle(.secondary)
                        Text("Right-click the poster for source and credits.").font(.system(size:10)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(18).background(.white,in:RoundedRectangle(cornerRadius:18))
            }.padding(28).frame(width:490,height:205).background(Color(red:243.0/255,green:248.0/255,blue:244.0/255)).foregroundStyle(Color(red:25.0/255,green:51.0/255,blue:38.0/255)).preferredColorScheme(.light)
        }.windowStyle(.hiddenTitleBar)
    }
}
@MainActor final class PreviewDelegate:NSObject,NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note:Notification) {NSApp.setActivationPolicy(.regular);NSApp.activate(ignoringOtherApps:true)}
    func applicationShouldTerminateAfterLastWindowClosed(_ app:NSApplication)->Bool {true}
}
