import SwiftUI

struct EmptyDownloadArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval:1.0/30.0,paused:reduceMotion || scenePhase != .active)) { context in
            let time=reduceMotion ? 0:context.date.timeIntervalSinceReferenceDate
            let pulse=sin(time * .pi / 3)
            let arrow=sin(time * .pi / 1.8)

            ZStack {
                Circle().fill(seedGreen.opacity(0.07)).frame(width:160,height:160)
                    .scaleEffect(1 + 0.035 * pulse)
                Circle().fill(seedGreen.opacity(0.09)).frame(width:115,height:115)
                    .scaleEffect(1 - 0.025 * pulse)
                Image(systemName:"arrow.down.to.line.compact")
                    .font(.system(size:48,weight:.light)).foregroundStyle(seedGreen)
                    .offset(y:reduceMotion ? 0:3.5 * arrow)
            }
            .frame(width:172,height:172)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
