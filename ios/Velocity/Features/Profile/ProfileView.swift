import SwiftUI

@MainActor
@Observable
final class ProfileVM {
    var season: SeasonResponse?
    var badges: BadgesResponse?
    var rank: Int?

    func load() async {
        async let s = try? APIClient.shared.season()
        async let b = try? APIClient.shared.badges()
        async let lb = try? APIClient.shared.leaderboard(board: "district")
        season = await s
        badges = await b
        rank = await lb?.entries.first(where: { $0.isMe })?.rank
    }
}

struct ProfileView: View {
    @Environment(AppState.self) private var app
    @State private var vm = ProfileVM()
    @State private var selectedBadge: Badge?
    @State private var editingProfile = false

    var body: some View {
        @Bindable var app = app
        let loc = app.loc
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if let me = app.me {
                        PassportCard(me: me, rank: vm.rank, loc: loc)
                        if let season = vm.season { SeasonCard(season: season, loc: loc) }
                        statsRow(me)
                        StreakCard(me: me, loc: loc)
                    }
                    if let badges = vm.badges { badgesGrid(badges) }
                    accountLists
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(ScreenBackground())
            .navigationTitle(loc.s("profileTitle"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editingProfile = true } label: { Image(systemName: "square.and.pencil").foregroundStyle(Theme.tint) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape.fill").foregroundStyle(Theme.tx2) }
                }
            }
            .task { await vm.load() }
            .sheet(item: $selectedBadge) { b in BadgeDetailSheet(badge: b, loc: loc) }
            .sheet(isPresented: $editingProfile) { EditProfileSheet() }
            .navigationDestination(item: $app.profilePush) { dest in
                switch dest {
                case .settings: SettingsView()
                case .rides: RidesView()
                case .about: AboutView()
                case .rules: RulesView()
                case .favorites: FavoritesView()
                case .reports: ContributionsView(filter: .reports)
                case .edits: ContributionsView(filter: .edits)
                }
            }
        }
    }

    private func statsRow(_ me: Me) -> some View {
        let loc = app.loc
        return HStack(spacing: 10) {
            StatTile(value: "\(Int(me.kmTotal))", label: "км", color: Theme.tint)
            StatTile(value: "\(me.stats.edits)", label: loc.s("xpEdits"), color: Theme.green)
            StatTile(value: "\(me.stats.reports)", label: loc.s("xpReports"), color: Theme.orange)
            StatTile(value: "\(me.stats.confirms)", label: loc.s("xpConf"), color: Theme.purple)
        }
    }

    private func badgesGrid(_ badges: BadgesResponse) -> some View {
        let loc = app.loc
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: loc.s("badgesL")) {
                Text("\(badges.earned)/\(badges.total)").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.tx2)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                ForEach(badges.badges) { b in
                    Button { selectedBadge = b } label: {
                        VStack(spacing: 6) {
                            BadgeSquare(badge: b)
                            Text(b.title(loc.lang)).font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.tx2).lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var accountLists: some View {
        let loc = app.loc
        return VStack(spacing: 14) {
            VCard(padding: 4) {
                VStack(spacing: 0) {
                    NavigationLink { FavoritesView() } label: { AccountRow(icon: "star.fill", color: Theme.orange, title: loc.s("favorites")) }
                    Divider().padding(.leading, 52)
                    NavigationLink { ContributionsView(filter: .reports) } label: { AccountRow(icon: "exclamationmark.bubble.fill", color: Theme.red, title: loc.s("myReports"), count: app.me?.stats.reports) }
                    Divider().padding(.leading, 52)
                    NavigationLink { ContributionsView(filter: .edits) } label: { AccountRow(icon: "pencil.and.outline", color: Theme.green, title: loc.s("myEdits"), count: app.me?.stats.edits) }
                }
            }
            VCard(padding: 4) {
                VStack(spacing: 0) {
                    NavigationLink { RidesView() } label: { AccountRow(icon: "bicycle", color: Theme.tint, title: loc.s("ridesItem")) }
                    Divider().padding(.leading, 52)
                    NavigationLink { SettingsView() } label: { AccountRow(icon: "gearshape.fill", color: Theme.tx2, title: loc.s("settingsItem")) }
                }
            }
        }
    }
}

// ── Passport hero ─────────────────────────────────────────────────────────────
struct PassportCard: View {
    let me: Me
    let rank: Int?
    let loc: Loc
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.hero, style: .continuous).fill(Theme.passport)
            VStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle().fill(.white).frame(width: 106, height: 106)
                        Text(me.avatarLetter).font(.system(size: 42, weight: .heavy)).foregroundStyle(.white)
                            .frame(width: 96, height: 96).background(Theme.avatar, in: Circle())
                    }
                    Text("LVL \(me.level.level)")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: 0x5B4BE0))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Theme.gold, in: Capsule())
                        .offset(x: 6, y: 4)
                }
                Text(me.nickname).font(.system(size: 23, weight: .heavy)).foregroundStyle(.white)
                PillTag("👑 \(me.title(loc.lang))", fg: .white, bg: Color.white.opacity(0.18), size: 13)
                HStack(spacing: 0) {
                    heroStat("\(me.points)", "XP")
                    divider
                    heroStat("#\(rank ?? 0)", loc.lang == .ru ? "ранг" : "rank")
                    divider
                    heroStat("\(me.streak.count)", loc.lang == .ru ? "серия" : "streak")
                }
                .padding(.top, 4)
            }
            .padding(22)
            .shine(radius: Radius.hero)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func heroStat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 18, weight: .heavy)).foregroundStyle(.white)
            Text(l).font(.system(size: 11)).foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }
    private var divider: some View { Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28) }
}

// ── Season / battle-pass ──────────────────────────────────────────────────────
struct SeasonCard: View {
    let season: SeasonResponse
    let loc: Loc
    var body: some View {
        VCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(season.title(loc.lang)).font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.tx)
                        Text("\(loc.s("timeLeft")) \(season.daysLeft) \(loc.s("daysShort"))").font(.system(size: 12)).foregroundStyle(Theme.tx2)
                    }
                    Spacer()
                    Text("\(loc.s("seasonTier")) \(season.currentTier)/\(season.tiers)")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.purple)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Theme.purple.opacity(0.15), in: Capsule())
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(season.rewards.enumerated()), id: \.element.id) { i, r in
                            if i > 0 {
                                Rectangle().fill(r.state == "locked" ? Theme.card2 : Theme.green)
                                    .frame(width: 22, height: 3)
                            }
                            VStack(spacing: 6) {
                                tierNode(r)
                                Text("Т\(r.tier)").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.tx3)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func tierNode(_ r: SeasonReward) -> some View {
        ZStack {
            switch r.state {
            case "done":
                Circle().fill(Theme.green).frame(width: 40, height: 40)
                Image(systemName: r.icon).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            case "current":
                Circle().fill(Theme.purple).frame(width: 40, height: 40)
                    .overlay(Circle().stroke(Theme.purple.opacity(0.4), lineWidth: 4).frame(width: 48, height: 48))
                    .shadow(color: Theme.purple.opacity(0.5), radius: 8)
                Image(systemName: r.icon).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            default:
                Circle().fill(Theme.card2).frame(width: 40, height: 40)
                Image(systemName: r.icon).font(.system(size: 15)).foregroundStyle(Theme.tx3)
            }
        }
        .frame(width: 48, height: 48)
    }
}

// ── Streak card ───────────────────────────────────────────────────────────────
struct StreakCard: View {
    let me: Me
    let loc: Loc
    var body: some View {
        VCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill").foregroundStyle(Theme.orange)
                        Text("\(loc.s("streakLabel")) · \(me.streak.count)").font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.tx)
                    }
                    Spacer()
                    Text("\(loc.s("streakRecord")) \(me.streak.best)").font(.system(size: 13)).foregroundStyle(Theme.tx2)
                }
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { i in
                        let done = i < min(7, me.streak.count)
                        ZStack {
                            Circle().fill(done ? Theme.orange : Theme.card2).frame(width: 34, height: 34)
                            if done { Image(systemName: "flame.fill").font(.system(size: 14)).foregroundStyle(.white) }
                        }
                        .overlay(Circle().stroke(i == 6 ? Theme.tx.opacity(0.25) : .clear, lineWidth: 2.5))
                        if i < 6 { Spacer(minLength: 0) }
                    }
                }
            }
        }
    }
}

// ── Badge square + detail ─────────────────────────────────────────────────────
struct BadgeSquare: View {
    let badge: Badge
    private var color: Color { Theme.token(badge.color) }
    var body: some View {
        ZStack {
            if badge.earned {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient.angled([color, color.opacity(0.65)], degrees: 150))
                    .shadow(color: color.opacity(0.4), radius: 6, y: 3)
                Image(systemName: badge.icon).font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card2)
                Image(systemName: "lock.fill").font(.system(size: 20)).foregroundStyle(Theme.tx3)
            }
        }
        .frame(width: 68, height: 68)
    }
}

struct BadgeDetailSheet: View {
    let badge: Badge
    let loc: Loc
    private var color: Color { Theme.token(badge.color) }
    var body: some View {
        VStack(spacing: 14) {
            Grabber()
            BadgeSquare(badge: badge).scaleEffect(1.4).frame(width: 98, height: 98).padding(.top, 18)
            Text(badge.title(loc.lang)).font(.system(size: 23, weight: .heavy)).foregroundStyle(Theme.tx)
            Text(badge.desc(loc.lang)).font(.system(size: 15)).foregroundStyle(Theme.tx2).multilineTextAlignment(.center)
            if badge.earned {
                Label(loc.s("earnedL"), systemImage: "checkmark.seal.fill").foregroundStyle(Theme.green).font(.system(size: 15, weight: .semibold))
            } else {
                VStack(spacing: 6) {
                    Text("\(loc.s("progressL")) · \(badge.progress)/\(badge.target)").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.tx2)
                    VProgressBar(value: Double(badge.progress) / Double(max(1, badge.target)), height: 8, fill: AnyShapeStyle(color))
                        .frame(width: 200)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .presentationDetents([.height(340)])
        .presentationBackground(Theme.bg)
    }
}

// ── Edit profile (ACC-3) ──────────────────────────────────────────────────────
struct EditProfileSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = ""
    @State private var busy = false

    var body: some View {
        let loc = app.loc
        NavigationStack {
            VStack(spacing: 22) {
                Text((nickname.first.map { String($0).uppercased() }) ?? "V")
                    .font(.system(size: 40, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 96, height: 96).background(Theme.avatar, in: Circle())
                    .padding(.top, 24)
                TextField(loc.s("nickname"), text: $nickname)
                    .font(.system(size: 17)).padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                Spacer()
            }
            .padding(16)
            .background(ScreenBackground())
            .navigationTitle(loc.s("editProfile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(loc.s("cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.s("save")) { save() }
                        .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                }
            }
            .onAppear { nickname = app.me?.nickname ?? "" }
        }
    }

    private func save() {
        busy = true
        let nn = nickname.trimmingCharacters(in: .whitespaces)
        let letter = String(nn.first ?? "V").uppercased()
        Task {
            _ = try? await APIClient.shared.patchMe(["nickname": nn, "avatarLetter": letter])
            await app.refreshMe()
            dismiss()
        }
    }
}

// ── Account row ───────────────────────────────────────────────────────────────
struct AccountRow: View {
    let icon: String
    let color: Color
    let title: String
    var count: Int? = nil
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 30, height: 30).background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title).font(.system(size: 16)).foregroundStyle(Theme.tx)
            Spacer()
            if let count { Text("\(count)").font(.system(size: 15)).foregroundStyle(Theme.tx2) }
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.tx3)
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
