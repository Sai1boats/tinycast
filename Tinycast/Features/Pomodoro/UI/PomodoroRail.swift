import SwiftUI

/// The countdown's hairline rail: the card's one piece of always-on progress.
struct PomodoroRail: View {
    var progress: Double
    var tint: Color
    var height: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Colors.border)
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, proxy.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
