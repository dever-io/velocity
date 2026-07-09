import SwiftUI

// ── Idle animations ───────────────────────────────────────────────────────────
private struct BobModifier: ViewModifier {
    @State private var on = false
    var distance: CGFloat
    var duration: Double
    func body(content: Content) -> some View {
        content.offset(y: on ? -distance : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

private struct FloatModifier: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .offset(y: on ? -9 : 0)
            .rotationEffect(.degrees(on ? 2.5 : -2.5))
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

private struct ShineModifier: ViewModifier {
    @State private var phase: CGFloat = -1.3
    var radius: CGFloat
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geo in
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, .white.opacity(0.30), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * 0.55)
                    .rotationEffect(.degrees(18))
                    .offset(x: phase * geo.size.width * 1.6)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: false)) { phase = 1.3 }
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .allowsHitTesting(false)
        )
    }
}

extension View {
    func bob(distance: CGFloat = 4, duration: Double = 3) -> some View { modifier(BobModifier(distance: distance, duration: duration)) }
    func float() -> some View { modifier(FloatModifier()) }
    func shine(radius: CGFloat = Radius.hero) -> some View { modifier(ShineModifier(radius: radius)) }
}

// ── Confetti burst ────────────────────────────────────────────────────────────
struct ConfettiBurst: View {
    var count: Int = 26
    @State private var go = false

    private struct Piece { let dx: CGFloat; let dy: CGFloat; let color: Color; let rot: Double; let w: CGFloat; let h: CGFloat }
    private let pieces: [Piece]

    init(count: Int = 26, seed: Int = 1) {
        self.count = count
        var rng = SeededRNG(seed: UInt64(seed) &* 2654435761 &+ 1)
        let palette: [Color] = [Theme.green, Theme.tint, Theme.orange, Theme.purple, Theme.pink, Theme.gold]
        var arr: [Piece] = []
        for i in 0..<count {
            let angle = Double(i) / Double(count) * 2 * .pi + rng.double() * 0.4
            let dist = CGFloat(90 + rng.double() * 130)
            arr.append(Piece(
                dx: CGFloat(cos(angle)) * dist,
                dy: CGFloat(sin(angle)) * dist - 40,
                color: palette[i % palette.count],
                rot: rng.double() * 540 - 270,
                w: CGFloat(6 + rng.double() * 6),
                h: CGFloat(9 + rng.double() * 6)
            ))
        }
        pieces = arr
    }

    var body: some View {
        ZStack {
            ForEach(0..<pieces.count, id: \.self) { i in
                let p = pieces[i]
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.w, height: p.h)
                    .rotationEffect(.degrees(go ? p.rot : 0))
                    .offset(x: go ? p.dx : 0, y: go ? p.dy : 0)
                    .opacity(go ? 0 : 1)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 1.2)) { go = true } }
        .allowsHitTesting(false)
    }
}

struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B9 : seed }
    mutating func next() -> UInt64 { state ^= state << 13; state ^= state >> 7; state ^= state << 17; return state }
    mutating func double() -> Double { Double(next() % 10000) / 10000.0 }
}

// ── Toast ─────────────────────────────────────────────────────────────────────
struct ToastData: Identifiable, Equatable {
    let id = UUID()
    let text: String
    var icon: String = "checkmark.circle.fill"
    var color: Color = Theme.green
    static func == (a: ToastData, b: ToastData) -> Bool { a.id == b.id }
}

struct ToastView: View {
    let toast: ToastData
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.icon).font(.system(size: 15, weight: .bold))
            Text(toast.text).font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(toast.color, in: Capsule())
        .vShadow()
        .padding(.horizontal, 16)
    }
}

// ── "+XP" fly-up ──────────────────────────────────────────────────────────────
struct XPFlyUp: View {
    let amount: Int
    @State private var up = false
    var body: some View {
        Text("+\(amount) XP")
            .font(.system(size: 17, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Theme.green, in: Capsule())
            .vShadowS()
            .scaleEffect(up ? 0.7 : 1)
            .offset(y: up ? -78 : 0)
            .opacity(up ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 1.1)) { up = true } }
            .allowsHitTesting(false)
    }
}
