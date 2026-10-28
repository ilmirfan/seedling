import SwiftUI

struct SeedlingButtonStyle: ButtonStyle {
    var prominent = false
    var circular = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius:circular ? 100:12)
        configuration.label
            .font(.system(size:12,weight:.semibold))
            .padding(.horizontal,circular ? 6:14)
            .padding(.vertical,circular ? 6:9)
            .foregroundStyle(prominent ? Color.white:ink)
            .background(prominent ? seedGreen:Color.white,in:shape)
            .overlay(shape.stroke(prominent ? Color.clear:ink.opacity(0.12),lineWidth:1))
            .opacity(!isEnabled ? 0.4:configuration.isPressed ? 0.75:1)
    }
}

extension View {
    func seedlingPlaybackButton(paused: Bool) -> some View {
        self.buttonStyle(SeedlingButtonStyle(prominent:paused,circular:true))
    }
    func seedlingButton(prominent: Bool = false,circular: Bool = false) -> some View {
        self.buttonStyle(SeedlingButtonStyle(prominent:prominent,circular:circular))
    }
}
