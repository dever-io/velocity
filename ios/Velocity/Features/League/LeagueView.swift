import SwiftUI

@MainActor
@Observable
final class LeagueVM {
    var data: LeagueResponse?
    func load() async { data = try? await APIClient.shared.league() }
}

struct LeagueView: View {
    @Environment(AppState.self) private var app
    @State private var vm = LeagueVM()

    var body: some View {
        let loc = app.loc
        ScrollView {
            VStack(spacing: 18) {
                if let d = vm.data {
                    emblem(d)
                    ladder(d)
                    zones(d)
                } else {
                    ProgressView().padding(.top, 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(ScreenBackground())
        .safeAreaInset(edge: .top) { header }
        .task { await vm.load() }
    }

    private var header: some View {
        let loc = app.loc
        return HStack {
            Text(loc.s("leagueTitle")).font(.system(size: 30, weight: .heavy)).tracking(-0.6).foregroundStyle(Theme.tx)
            Spacer()
            if let d = vm.data {
                PillTag("\(d.daysLeft) \(loc.s("daysShort"))", fg: Theme.tx, bg: Theme.card, icon: "timer", size: 13)
                    .vShadowS()
            }
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
        .background(Theme.bg)
    }

    private func emblem(_ d: LeagueResponse) -> some View {
        let loc = app.loc
        let current = d.ladder.first { $0.current }
        return ZStack {
            RoundedRectangle(cornerRadius: Radius.hero, style: .continuous).fill(Theme.leagueGold)
            VStack(spacing: 10) {
                ZStack {
                    Image(systemName: "shield.fill").font(.system(size: 66)).foregroundStyle(.white.opacity(0.95))
                    Image(systemName: "star.fill").font(.system(size: 26)).foregroundStyle(Theme.leagueGold)
                }
                Text(current?.title(loc.lang) ?? "").font(.system(size: 23, weight: .heavy)).foregroundStyle(.white)
                Text(loc.s("leaguePromoNote")).font(.system(size: 13)).foregroundStyle(.white.opacity(0.85))
            }
            .padding(22)
            .shine(radius: Radius.hero)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func ladder(_ d: LeagueResponse) -> some View {
        HStack(spacing: 6) {
            ForEach(d.ladder) { tier in
                let c = Theme.leagueColor(tier.id)
                Text(tier.title(app.lang).split(separator: " ").first.map(String.init) ?? tier.id)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tier.current ? .white : Theme.tx2)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(tier.current ? c : Theme.card2, in: Capsule())
                    .scaleEffect(tier.current ? 1.06 : 1)
            }
        }
    }

    private func zones(_ d: LeagueResponse) -> some View {
        let loc = app.loc
        let promo = d.entries.filter { ($0.rank ?? 99) <= d.promotion }
        let rest = d.entries.filter { ($0.rank ?? 99) > d.promotion }
        let demoteFrom = d.entries.count - d.demotion
        return VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label(loc.s("leaguePromo"), systemImage: "arrow.up")
                    .font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.green)
                VCard(padding: 6) {
                    VStack(spacing: 0) {
                        ForEach(Array(promo.enumerated()), id: \.element.id) { i, e in
                            LeaderRow(entry: e)
                            if i < promo.count - 1 { Divider().padding(.leading, 44) }
                        }
                    }
                }
            }
            if !rest.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    VCard(padding: 6) {
                        VStack(spacing: 0) {
                            ForEach(Array(rest.enumerated()), id: \.element.id) { i, e in
                                let isDemote = (e.rank ?? 0) > demoteFrom
                                LeaderRow(entry: e)
                                    .background(isDemote ? Theme.red.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 11))
                                if i < rest.count - 1 { Divider().padding(.leading, 44) }
                            }
                        }
                    }
                    Label(loc.s("leagueDemo"), systemImage: "arrow.down")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.red)
                }
            }
        }
    }
}
