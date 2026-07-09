import SwiftUI
import CoreLocation

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        ZStack {
            switch app.phase {
            case .onboarding: OnboardingView()
            case .auth: AuthView()
            case .app: AppShell()
            }
        }
        .overlay(alignment: .top) {
            if let toast = app.toast {
                ToastView(toast: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(toast.id)
            }
        }
        .overlay {
            if app.confettiSeed > 0 {
                ConfettiBurst(seed: app.confettiSeed)
                    .id(app.confettiSeed)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .offset(y: -80)
            }
        }
        .overlay {
            if let amount = app.xpFly {
                XPFlyUp(amount: amount)
                    .id(amount)
                    .offset(y: -40)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: app.toast)
        .fullScreenCover(item: $app.levelUp) { info in
            LevelUpView(info: info)
        }
        .preferredColorScheme(app.colorScheme)
        .tint(Theme.tint)
    }
}

// ── App shell: custom tab bar + content + "+" action sheet ────────────────────
enum AppCover: Int, Identifiable { case report, draw, poi, route; var id: Int { rawValue } }

struct AppShell: View {
    @Environment(AppState.self) private var app
    @State private var showPlus = false

    var body: some View {
        @Bindable var app = app
        ZStack(alignment: .bottom) {
            Group {
                switch app.selectedTab {
                case 0: HomeView()
                case 1: MapScreen()
                case 3: LeagueView()
                case 4: ProfileView()
                default: HomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VeloTabBar(selected: $app.selectedTab, onPlus: { showPlus = true })
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showPlus) {
            PlusActionSheet { chosen in
                showPlus = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { app.cover = chosen }
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
        }
        .fullScreenCover(item: $app.cover) { c in
            switch c {
            case .report: ReportFlow(coordinate: MapDefaults.center)
            case .draw: DrawFlow()
            case .poi: AddPOIFlow(coordinate: MapDefaults.center)
            case .route: RouteView()
            }
        }
    }
}

// ── Custom tab bar ────────────────────────────────────────────────────────────
struct VeloTabBar: View {
    @Environment(AppState.self) private var app
    @Binding var selected: Int
    let onPlus: () -> Void

    private struct Item { let idx: Int; let icon: String; let fill: String; let key: String }
    private var items: [Item] {
        [
            Item(idx: 0, icon: "house", fill: "house.fill", key: "tHome"),
            Item(idx: 1, icon: "map", fill: "map.fill", key: "tMap"),
            Item(idx: 3, icon: "trophy", fill: "trophy.fill", key: "tQuests"),
            Item(idx: 4, icon: "person", fill: "person.fill", key: "tProfile"),
        ]
    }

    var body: some View {
        let loc = app.loc
        HStack(alignment: .top, spacing: 0) {
            tab(items[0])
            tab(items[1])
            plusButton
            tab(items[2])
            tab(items[3])
        }
        .padding(.top, 8)
        .padding(.horizontal, 6)
        .frame(height: 58, alignment: .top)
        .padding(.bottom, safeBottom())
        .background(
            Theme.card
                .overlay(alignment: .top) { Rectangle().fill(Theme.sep).frame(height: 0.5) }
                .ignoresSafeArea(edges: .bottom)
        )
        .environment(\.loc, loc)
    }

    private func tab(_ item: Item) -> some View {
        let active = selected == item.idx
        return Button {
            selected = item.idx
        } label: {
            VStack(spacing: 4) {
                Image(systemName: active ? item.fill : item.icon)
                    .font(.system(size: 23, weight: .regular))
                Text(app.loc.s(item.key))
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(active ? Theme.tint : Theme.tx3)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var plusButton: some View {
        Button(action: onPlus) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 34)
                .background(Theme.tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color(hex: 0x005ADC).opacity(0.4), radius: 8, x: 0, y: 6)
        }
        .frame(maxWidth: .infinity)
        .offset(y: -2)
    }

    private func safeBottom() -> CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom ?? 0
    }
}

// ── "+" action sheet ──────────────────────────────────────────────────────────
struct PlusActionSheet: View {
    @Environment(AppState.self) private var app
    let onChoose: (AppCover) -> Void

    var body: some View {
        let loc = app.loc
        VStack(spacing: 10) {
            Spacer()
            VStack(spacing: 0) {
                Text(loc.s("actionTitle"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.tx2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                Divider()
                row(icon: "exclamationmark.triangle.fill", title: loc.s("aReport"), color: Theme.red) { onChoose(.report) }
                Divider()
                row(icon: "pencil.and.outline", title: loc.s("aDraw"), color: Theme.green) { onChoose(.draw) }
                Divider()
                row(icon: "mappin.circle.fill", title: loc.s("aPoi"), color: Theme.tint) { onChoose(.poi) }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            Button { app.toast = nil; dismissSheet() } label: {
                Text(loc.s("cancel"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.tint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    @Environment(\.dismiss) private var dismiss
    private func dismissSheet() { dismiss() }

    private func row(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).frame(width: 26)
                Text(title).font(.system(size: 17, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(color)
            .padding(.horizontal, 18)
            .frame(height: 57)
        }
    }
}

// Shared map defaults (Khamovniki / Gorky Park area).
enum MapDefaults {
    static let center = CLLocationCoordinate2D(latitude: 55.7295, longitude: 37.593)
}

// Environment key so nested views can read the active Loc.
private struct LocKey: EnvironmentKey { static let defaultValue = Loc(lang: .ru) }
extension EnvironmentValues {
    var loc: Loc {
        get { self[LocKey.self] }
        set { self[LocKey.self] = newValue }
    }
}
