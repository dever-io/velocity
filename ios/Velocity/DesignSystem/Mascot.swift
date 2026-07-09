import SwiftUI

// Original geometric mascot — a purple bike-helmet buddy (README §Assets).
// `cheering` raises the arms for the level-up celebration.
struct Mascot: View {
    var size: CGFloat = 120
    var cheering: Bool = false

    private var helmet: Color { Theme.mascotHelmet }
    private var face: Color { Color(hex: 0xF3F0FF) }

    var body: some View {
        ZStack {
            // Arms
            arm(angle: cheering ? -55 : -18)
                .offset(x: -size * 0.36, y: cheering ? -size * 0.06 : size * 0.12)
            arm(angle: cheering ? 55 : 18)
                .offset(x: size * 0.36, y: cheering ? -size * 0.06 : size * 0.12)
                .scaleEffect(x: -1, y: 1)

            // Body
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(helmet.opacity(0.9))
                .frame(width: size * 0.5, height: size * 0.42)
                .offset(y: size * 0.34)

            // Head
            ZStack {
                Circle().fill(face)
                // Helmet dome
                Circle().fill(helmet)
                    .frame(width: size * 0.72, height: size * 0.72)
                    .offset(y: -size * 0.16)
                    .mask(Circle().frame(width: size * 0.72, height: size * 0.72))
                // Helmet rim
                Capsule().fill(.white.opacity(0.9))
                    .frame(width: size * 0.62, height: size * 0.07)
                    .offset(y: -size * 0.02)
                // Helmet vent
                Capsule().fill(helmet.opacity(0.6))
                    .frame(width: size * 0.16, height: size * 0.05)
                    .offset(y: -size * 0.22)
                // Eyes
                HStack(spacing: size * 0.12) {
                    eye
                    eye
                }
                .offset(y: size * 0.06)
                // Smile
                Smile()
                    .stroke(helmet, style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
                    .frame(width: size * 0.26, height: size * 0.12)
                    .offset(y: size * 0.2)
            }
            .frame(width: size * 0.72, height: size * 0.72)
            .clipShape(Circle())
        }
        .frame(width: size, height: size)
    }

    private var eye: some View {
        ZStack {
            Circle().fill(.white).frame(width: size * 0.14, height: size * 0.14)
            Circle().fill(Color(hex: 0x2A1E5C)).frame(width: size * 0.07, height: size * 0.07)
        }
    }

    private func arm(angle: Double) -> some View {
        Capsule()
            .fill(helmet.opacity(0.9))
            .frame(width: size * 0.12, height: size * 0.28)
            .rotationEffect(.degrees(angle))
    }
}

private struct Smile: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY * 1.6))
        return p
    }
}
