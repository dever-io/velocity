import SwiftUI

// ── Card container ────────────────────────────────────────────────────────────
struct VCard<Content: View>: View {
    var padding: CGFloat = 16
    var radius: CGFloat = Radius.card
    var background: Color = Theme.card
    var shadow: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .modifier(CardShadow(on: shadow))
    }
}

private struct CardShadow: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View { on ? AnyView(content.vShadow()) : AnyView(content) }
}

// ── Buttons ───────────────────────────────────────────────────────────────────
struct PrimaryButton: View {
    let title: String
    var color: Color = Theme.tint
    var textColor: Color = .white
    var enabled: Bool = true
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 17, weight: .semibold)) }
                Text(title).font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(color, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// ── Pills / chips ─────────────────────────────────────────────────────────────
struct PillTag: View {
    let text: String
    var fg: Color = .white
    var bg: AnyShapeStyle
    var icon: String? = nil
    var size: CGFloat = 13

    init(_ text: String, fg: Color = .white, bg: Color, icon: String? = nil, size: CGFloat = 13) {
        self.text = text; self.fg = fg; self.bg = AnyShapeStyle(bg); self.icon = icon; self.size = size
    }
    init(_ text: String, fg: Color = .white, gradient: LinearGradient, icon: String? = nil, size: CGFloat = 13) {
        self.text = text; self.fg = fg; self.bg = AnyShapeStyle(gradient); self.icon = icon; self.size = size
    }

    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.system(size: size - 1, weight: .bold)) }
            Text(text).font(.system(size: size, weight: .bold))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(bg, in: Capsule())
    }
}

struct IconChip: View {
    let system: String
    var color: Color = Theme.tint
    var size: CGFloat = 46
    var iconSize: CGFloat = 20
    var body: some View {
        Image(systemName: system)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

// ── Progress bar ──────────────────────────────────────────────────────────────
struct VProgressBar: View {
    var value: Double            // 0...1
    var height: CGFloat = 7
    var fill: AnyShapeStyle = AnyShapeStyle(Theme.tint)
    var track: Color = Theme.card2

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(fill)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// ── Level ring ────────────────────────────────────────────────────────────────
struct LevelRing<Center: View>: View {
    var progress: Double
    var size: CGFloat = 84
    var lineWidth: CGFloat = 8
    var track: Color = .white.opacity(0.25)
    var ring: Color = .white
    @ViewBuilder var center: Center

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(ring, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center
        }
        .frame(width: size, height: size)
    }
}

// ── Gradient avatar ───────────────────────────────────────────────────────────
struct GradientAvatar: View {
    let letter: String
    var size: CGFloat = 34
    var gradient: LinearGradient = Theme.avatar
    var body: some View {
        Text(letter)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(gradient, in: Circle())
    }
}

// ── Section header ────────────────────────────────────────────────────────────
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 20, weight: .heavy)).tracking(-0.3)
                .foregroundStyle(Theme.tx)
            Spacer()
            trailing
        }
    }
}
extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) { self.init(title: title) { EmptyView() } }
}

// ── Stat tile ─────────────────────────────────────────────────────────────────
struct StatTile: View {
    let value: String
    let label: String
    var color: Color = Theme.tx
    var body: some View {
        VCard(padding: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(value).font(.system(size: 21, weight: .heavy)).foregroundStyle(color)
                Text(label).font(.system(size: 12)).foregroundStyle(Theme.tx2)
            }
        }
    }
}

// ── Rank medal ────────────────────────────────────────────────────────────────
struct RankMedal: View {
    let rank: Int
    var size: CGFloat = 26
    var body: some View {
        Group {
            if rank <= 3 {
                Text("\(rank)")
                    .font(.system(size: size * 0.5, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(medalColor, in: Circle())
            } else {
                Text("\(rank)")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(Theme.tx2)
                    .frame(width: size, height: size)
            }
        }
    }
    private var medalColor: Color {
        switch rank {
        case 1: return Color(hex: 0xFFC400)
        case 2: return Color(hex: 0xB8BEC9)
        default: return Color(hex: 0xCD7F32)
        }
    }
}

// ── Grabber for sheets ────────────────────────────────────────────────────────
struct Grabber: View {
    var body: some View {
        Capsule().fill(Theme.hair).frame(width: 38, height: 5).padding(.top, 8)
    }
}

// ── Screen background ─────────────────────────────────────────────────────────
struct ScreenBackground: View {
    var body: some View { Theme.bg.ignoresSafeArea() }
}
