import SwiftUI

struct DistanceMark: View {
    var height: CGFloat = 88

    var body: some View {
        Canvas { context, size in
            let left = CGPoint(x: size.width * 0.18, y: size.height * 0.68)
            let right = CGPoint(x: size.width * 0.82, y: size.height * 0.36)
            var path = Path()
            path.move(to: left)
            path.addQuadCurve(
                to: right,
                control: CGPoint(x: size.width * 0.52, y: size.height * 0.05)
            )
            context.stroke(path, with: .color(Palette.ink.opacity(0.55)), lineWidth: 1.5)
            let dot = 7.0
            context.fill(
                Path(ellipseIn: CGRect(x: left.x - dot, y: left.y - dot, width: dot * 2, height: dot * 2)),
                with: .color(Palette.ink)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: right.x - dot, y: right.y - dot, width: dot * 2, height: dot * 2)),
                with: .color(Palette.coral)
            )
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
