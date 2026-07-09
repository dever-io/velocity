import SwiftUI
import CoreLocation

enum ThemeMode: String, CaseIterable { case system, light, dark }
enum AppPhase { case onboarding, auth, app }

struct RoutePoint: Equatable {
    let name: String
    let lat: Double
    let lng: Double
    var coord: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
}

enum ProfilePush: String, Identifiable { case settings, rides, about, rules, favorites, reports, edits; var id: String { rawValue } }

struct LevelUpInfo: Identifiable {
    let id = UUID()
    let newLevel: Int
    let badge: Badge?
}

@MainActor
@Observable
final class AppState {
    var lang: Lang { didSet { UserDefaults.standard.set(lang.rawValue, forKey: "lang") } }
    var themeMode: ThemeMode { didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: "theme") } }
    var onboardingSeen: Bool { didSet { UserDefaults.standard.set(onboardingSeen, forKey: "obSeen") } }

    var me: Me?
    var isSigningIn = false

    // Transient reward UI
    var toast: ToastData?
    var confettiSeed = 0
    var xpFly: Int?
    var levelUp: LevelUpInfo?

    var selectedTab = 0

    // Global full-screen cover presentation (one cover per host view in SwiftUI,
    // so report/draw/poi/route all funnel through a single enum).
    var cover: AppCover?
    var routeDestination: RoutePoint?
    var profilePush: ProfilePush?
    var cardArg: String?   // test: -card segment|poi|report

    var loc: Loc { Loc(lang: lang) }

    func startRoute(to dest: RoutePoint? = nil) {
        routeDestination = dest
        cover = .route
    }

    var phase: AppPhase {
        if !onboardingSeen { return .onboarding }
        return me == nil ? .auth : .app
    }

    var colorScheme: ColorScheme? {
        switch themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    init() {
        let d = UserDefaults.standard
        let stored = d.string(forKey: "lang")
        lang = Lang(rawValue: stored ?? "") ?? .ru
        themeMode = ThemeMode(rawValue: d.string(forKey: "theme") ?? "") ?? .system
        onboardingSeen = d.bool(forKey: "obSeen")
    }

    func bootstrap() async {
        if let t = Keychain.load() {
            APIClient.shared.token = t
            do { me = try await APIClient.shared.me() }
            catch { Keychain.clear(); APIClient.shared.token = nil; me = nil }
        }
        // Test affordance: `-auth` shows the signed-out auth screen.
        if CommandLine.arguments.contains("-auth") {
            onboardingSeen = true
            signOut()
            return
        }
        // Test affordance: `-autologin` launch arg skips onboarding + dev sign-in
        // so authed screens can be screenshotted headlessly.
        if CommandLine.arguments.contains("-autologin") {
            onboardingSeen = true
            if me == nil { await signInDev() }
        }
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-lang"), i + 1 < args.count, let l = Lang(rawValue: args[i + 1]) {
            lang = l
        }
        if let i = args.firstIndex(of: "-theme"), i + 1 < args.count, let t = ThemeMode(rawValue: args[i + 1]) {
            themeMode = t
        }
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let t = Int(args[i + 1]) {
            selectedTab = t
        }
        if let i = args.firstIndex(of: "-card"), i + 1 < args.count { cardArg = args[i + 1] }
        let deep: (@escaping () -> Void) -> Void = { action in
            Task { try? await Task.sleep(nanoseconds: 800_000_000); action() }
        }
        if let i = args.firstIndex(of: "-flow"), i + 1 < args.count {
            let flow = args[i + 1]
            deep {
                switch flow {
                case "report": self.cover = .report
                case "draw": self.cover = .draw
                case "poi": self.cover = .poi
                case "route": self.cover = .route
                default: break
                }
            }
        }
        if args.contains("-levelup") {
            deep { self.levelUp = LevelUpInfo(newLevel: (self.me?.level.level ?? 8), badge: nil) }
        }
        if args.contains("-reward") {
            deep { self.handleReward(Reward(points: 1176, prevLevel: 8, level: 8, leveledUp: false, delta: 50), toast: "+50 XP") }
        }
        if let i = args.firstIndex(of: "-push"), i + 1 < args.count, let d = ProfilePush(rawValue: args[i + 1]) {
            selectedTab = 4
            deep { self.profilePush = d }
        }
    }

    func signInDev() async {
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let name = lang == .ru ? "Аня В." : "Anya V."
            let resp = try await APIClient.shared.authDev(name: name, letter: "А", locale: lang.rawValue)
            Keychain.save(resp.token)
            APIClient.shared.token = resp.token
            me = resp.user
        } catch {
            showToast(loc.s("netError"), icon: "wifi.slash", color: Theme.red)
        }
    }

    func completeOnboarding() { onboardingSeen = true }

    func signOut() {
        Keychain.clear()
        APIClient.shared.token = nil
        me = nil
    }

    func deleteAccount() async {
        try? await APIClient.shared.deleteMe()
        signOut()
    }

    func refreshMe() async { me = try? await APIClient.shared.me() }

    /// Central reward presentation: level-up → celebration; otherwise confetti + "+XP" + toast.
    func handleReward(_ reward: Reward?, toast text: String, unlockedBadge: Badge? = nil) {
        if let reward {
            Task { await refreshMe() }
            if reward.leveledUp {
                levelUp = LevelUpInfo(newLevel: reward.level, badge: unlockedBadge)
            } else {
                confettiSeed += 1
                presentXP(reward.delta)
                showToast(text)
            }
        } else {
            showToast(text)
        }
    }

    func presentXP(_ amount: Int) {
        xpFly = amount
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if xpFly == amount { xpFly = nil }
        }
    }

    func showToast(_ text: String, icon: String = "checkmark.circle.fill", color: Color = Theme.green) {
        let t = ToastData(text: text, icon: icon, color: color)
        toast = t
        Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if toast?.id == t.id { toast = nil }
        }
    }
}
