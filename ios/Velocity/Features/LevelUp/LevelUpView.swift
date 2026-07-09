import SwiftUI

struct LevelUpView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let info: LevelUpInfo

    @State private var spin = false
    @State private var ringProgress: CGFloat = 0
    @State private var beat = false

    var body: some View {
        let loc = app.loc
        ZStack {
            Theme.levelUpBg.ignoresSafeArea()
            SunburstRays()
                .rotationEffect(.degrees(spin ? 360 : 0))
                .opacity(0.5)
            TwinkleStars()

            VStack(spacing: 0) {
                Spacer()
                Mascot(size: 128, cheering: true).float()
                Text(loc.s("levelUpOverline"))
                    .font(.system(size: 14, weight: .heavy)).tracking(3)
                    .foregroundStyle(Theme.gold)
                    .padding(.top, 18)

                ZStack {
                    Circle().stroke(.white.opacity(0.18), lineWidth: 12).frame(width: 172, height: 172)
                    Circle().trim(from: 0, to: ringProgress)
                        .stroke(LinearGradient.angled([Theme.gold, Theme.pink], degrees: 140),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 172, height: 172)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: -4) {
                        Text("LVL").font(.system(size: 15, weight: .bold)).foregroundStyle(.white.opacity(0.75))
                        Text("\(info.newLevel)").font(.system(size: 60, weight: .black, design: .rounded)).foregroundStyle(.white)
                            .scaleEffect(beat ? 1.08 : 1)
                    }
                }
                .padding(.top, 22)

                Text(app.me?.title(loc.lang) ?? "")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 16)

                if let badge = info.badge {
                    HStack(spacing: 12) {
                        BadgeCircle(badge: badge, size: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc.s("newBadge")).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                            Text(badge.title(loc.lang)).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                }

                Spacer()
                PrimaryButton(title: loc.s("next"), color: .white, textColor: Color(hex: 0x201248)) { dismiss() }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 44)
            }

            ConfettiBurst(seed: info.newLevel).offset(y: -60)
        }
        .onAppear {
            withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeOut(duration: 1.1)) { ringProgress = 0.78 }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true).delay(0.6)) { beat = true }
        }
    }
}

private struct SunburstRays: View {
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height * 0.4)
            let r = max(size.width, size.height)
            let n = 24
            for i in 0..<n where i % 2 == 0 {
                let a0 = Double(i) / Double(n) * 2 * .pi
                let a1 = Double(i + 1) / Double(n) * 2 * .pi
                var p = Path()
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x + cos(a0) * r, y: c.y + sin(a0) * r))
                p.addLine(to: CGPoint(x: c.x + cos(a1) * r, y: c.y + sin(a1) * r))
                p.closeSubpath()
                ctx.fill(p, with: .color(.white.opacity(0.10)))
            }
        }
        .ignoresSafeArea()
    }
}

private struct TwinkleStars: View {
    private let stars: [(CGFloat, CGFloat, Double)] = [
        (0.15, 0.2, 0), (0.85, 0.18, 0.4), (0.25, 0.72, 0.8), (0.78, 0.66, 0.2),
        (0.5, 0.12, 0.6), (0.12, 0.5, 1.0), (0.9, 0.45, 0.3), (0.4, 0.82, 0.5),
    ]
    @State private var on = false
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<stars.count, id: \.self) { i in
                Text("✦")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.gold)
                    .opacity(on ? 1 : 0.4)
                    .scaleEffect(on ? 1.1 : 0.6)
                    .position(x: stars[i].0 * geo.size.width, y: stars[i].1 * geo.size.height)
                    .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true).delay(stars[i].2), value: on)
            }
        }
        .onAppear { on = true }
        .allowsHitTesting(false)
    }
}
