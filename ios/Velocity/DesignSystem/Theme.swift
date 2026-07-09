import SwiftUI

// Design tokens from the VeloQuest handoff (README §Design Tokens). Colors are
// dynamic UIColors so they resolve to the active light/dark trait (and respect
// the app's .preferredColorScheme override in Settings).

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
    /// Dynamic color that follows the resolved interface style.
    init(l: UIColor, d: UIColor) {
        self = Color(UIColor { $0.userInterfaceStyle == .dark ? d : l })
    }
}

private func ui(_ hex: UInt, _ a: Double = 1) -> UIColor {
    UIColor(
        red: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: a
    )
}

enum Theme {
    // Surfaces
    static let bg = Color(l: ui(0xEFEFF4), d: ui(0x000000))
    static let card = Color(l: ui(0xFFFFFF), d: ui(0x1C1C1E))
    static let card2 = Color(l: ui(0xF7F7FA), d: ui(0x2C2C2E))
    static let sep = Color(l: ui(0x3C3C43, 0.13), d: ui(0x545458, 0.40))
    static let hair = Color(l: ui(0x3C3C43, 0.29), d: ui(0x545458, 0.65))

    // Text
    static let tx = Color(l: ui(0x000000), d: ui(0xFFFFFF))
    static let tx2 = Color(l: ui(0x3C3C43, 0.60), d: ui(0xEBEBF5, 0.62))
    static let tx3 = Color(l: ui(0x3C3C43, 0.32), d: ui(0xEBEBF5, 0.32))

    // Accents
    static let tint = Color(l: ui(0x007AFF), d: ui(0x0A84FF))
    static let green = Color(l: ui(0x34C759), d: ui(0x30D158))
    static let red = Color(l: ui(0xFF3B30), d: ui(0xFF453A))
    static let orange = Color(l: ui(0xFF9500), d: ui(0xFF9F0A))
    static let purple = Color(l: ui(0xAF52DE), d: ui(0xBF5AF2))
    static let yellow = Color(l: ui(0xFFCC00), d: ui(0xFFD60A))
    static let teal = Color(l: ui(0x30B0C7), d: ui(0x40C8E0))

    // Infrastructure colors
    static let cProt = Color(l: ui(0x2FA84F), d: ui(0x32D74B))
    static let cLane = Color(l: ui(0xFF9500), d: ui(0xFF9F0A))
    static let cShared = Color(l: ui(0x9AA0A6), d: ui(0x8E8E93))
    static let cMtb = Color(l: ui(0xAF52DE), d: ui(0xBF5AF2))
    static let cOther = Color(l: ui(0x30B0C7), d: ui(0x40C8E0))

    static let appleBg = Color(l: ui(0x000000), d: ui(0xFFFFFF))
    static let appleFg = Color(l: ui(0xFFFFFF), d: ui(0x000000))

    // Fixed gamification accents (both themes)
    static let gold = Color(hex: 0xFFD34D)
    static let pink = Color(hex: 0xFF7AC8)
    static let mascotHelmet = Color(hex: 0x7B5CFF)

    // League tier colors
    static func leagueColor(_ id: String) -> Color {
        switch id {
        case "bronze": return Color(hex: 0xCD7F32)
        case "silver": return Color(hex: 0xB8BEC9)
        case "gold": return Color(hex: 0xFFC400)
        case "platinum": return Color(hex: 0x5AC8FA)
        case "diamond": return Color(hex: 0xAF52DE)
        default: return tint
        }
    }

    /// Map a token name (from the backend) to a Color.
    static func token(_ name: String) -> Color {
        switch name {
        case "tint": return tint
        case "green": return green
        case "red": return red
        case "orange": return orange
        case "purple": return purple
        case "yellow": return yellow
        case "teal": return teal
        case "avatar": return orange
        default: return tint
        }
    }

    // Gradients
    static let hubLevel = LinearGradient.angled([Color(hex: 0x6C5CE7), Color(hex: 0xA742F5), Color(hex: 0xFF5CA8)], degrees: 140)
    static let passport = LinearGradient.angled([Color(hex: 0x5B4BE0), Color(hex: 0x9A3FE8), Color(hex: 0xE24FA0)], degrees: 150)
    static let avatar = LinearGradient.angled([Color(hex: 0xFF9500), Color(hex: 0xFF375F)], degrees: 150)
    static let streakChip = LinearGradient.angled([Color(hex: 0xFF9F0A), Color(hex: 0xFF375F)], degrees: 135)
    static let leagueGold = LinearGradient.angled([Color(hex: 0xFFB020), Color(hex: 0xFF7A00)], degrees: 150)
    static let appIcon = LinearGradient.angled([Color(hex: 0x0A84FF), Color(hex: 0x0056D6)], degrees: 160)
    static let levelUpBg = RadialGradient(colors: [Color(hex: 0x3B2A86), Color(hex: 0x201248), Color(hex: 0x0E0824)], center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 520)

    static func infraColor(_ kind: String) -> Color {
        switch kind {
        case "prot": return cProt
        case "lane": return cLane
        case "shared": return cShared
        case "mtb": return cMtb
        default: return cOther
        }
    }

    static func poiColor(_ kind: String) -> Color {
        switch kind {
        case "workshop": return orange
        case "parking": return tint
        case "fountain": return teal
        case "rental": return green
        default: return tint
        }
    }

    static func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "pothole", "hazard": return red
        case "closure": return orange
        case "glass": return orange
        default: return red
        }
    }
}

extension LinearGradient {
    /// CSS-style angle gradient (0deg = up, clockwise).
    static func angled(_ colors: [Color], degrees: Double) -> LinearGradient {
        let a = degrees * .pi / 180
        let sx = 0.5 - 0.5 * sin(a)
        let sy = 0.5 + 0.5 * cos(a)
        let ex = 0.5 + 0.5 * sin(a)
        let ey = 0.5 - 0.5 * cos(a)
        return LinearGradient(colors: colors, startPoint: UnitPoint(x: sx, y: sy), endPoint: UnitPoint(x: ex, y: ey))
    }
}

// Shadows
extension View {
    func vShadow() -> some View { shadow(color: .black.opacity(0.16), radius: 13, x: 0, y: 8) }
    func vShadowS() -> some View { shadow(color: .black.opacity(0.10), radius: 5, x: 0, y: 2) }
}

enum Radius {
    static let button: CGFloat = 14
    static let card: CGFloat = 17
    static let hero: CGFloat = 24
    static let sheet: CGFloat = 22
    static let pill: CGFloat = 14
}
