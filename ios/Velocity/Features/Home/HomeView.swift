import SwiftUI

@MainActor
@Observable
final class HomeVM {
    var quests: [Quest] = []
    var badges: [Badge] = []
    var district: [LeaderEntry] = []

    func load() async {
        async let q = try? APIClient.shared.quests()
        async let b = try? APIClient.shared.badges()
        async let d = try? APIClient.shared.leaderboard(board: "district")
        quests = await q ?? quests
        badges = await b?.badges ?? badges
        district = await d?.entries ?? district
    }

    func claim(_ id: String) async -> Reward? {
        let r = try? await APIClient.shared.claimQuest(id)
        await load()
        return r?.reward
    }
}

struct HomeView: View {
    @Environment(AppState.self) private var app
    @State private var vm = HomeVM()

    var body: some View {
        let loc = app.loc
        ScrollView {
            VStack(spacing: 20) {
                header
                if let me = app.me { HeroLevelCard(me: me, loc: loc) }
                quickActions
                questsSection
                badgesSection
                leaderboardSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(ScreenBackground())
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    // Header
    private var header: some View {
        let loc = app.loc
        let first = (app.me?.nickname.split(separator: " ").first).map(String.init) ?? "🚲"
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(loc.s("hubHi")), \(first)!")
                    .font(.system(size: 27, weight: .heavy)).tracking(-0.6)
                    .foregroundStyle(Theme.tx)
                Text(loc.s("hubSub"))
                    .font(.system(size: 14)).foregroundStyle(Theme.tx2)
            }
            Spacer()
            PillTag("\(app.me?.streak.count ?? 0)", gradient: Theme.streakChip, icon: "flame.fill", size: 14)
        }
    }

    // Quick actions
    private var quickActions: some View {
        let loc = app.loc
        return HStack(spacing: 10) {
            QuickActionTile(icon: "point.topleft.down.to.point.bottomright.curvepath", label: loc.s("tRoute"), color: Theme.tint) { app.startRoute() }
            QuickActionTile(icon: "exclamationmark.triangle.fill", label: loc.s("qaReport"), color: Theme.red) { app.cover = .report }
            QuickActionTile(icon: "pencil.and.outline", label: loc.s("qaLane"), color: Theme.green) { app.cover = .draw }
        }
    }

    // Daily quests
    private var questsSection: some View {
        let loc = app.loc
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: loc.s("dailyQuests")) {
                Text(loc.s("questRefresh")).font(.system(size: 12)).foregroundStyle(Theme.tx3)
            }
            ForEach(vm.quests) { q in
                QuestCard(quest: q, loc: loc) {
                    Task {
                        let reward = await vm.claim(q.id)
                        app.handleReward(reward, toast: "+\(reward?.delta ?? q.rewardXp) XP")
                    }
                }
            }
        }
    }

    // Badges row
    private var badgesSection: some View {
        let loc = app.loc
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(loc.s("badgesL"))
            HStack(spacing: 12) {
                ForEach(vm.badges.prefix(4)) { b in
                    BadgeCircle(badge: b)
                    if b.id != vm.badges.prefix(4).last?.id { Spacer(minLength: 0) }
                }
            }
        }
    }

    // Leaderboard peek
    private var leaderboardSection: some View {
        let loc = app.loc
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: loc.s("leaderboard")) {
                Button(loc.s("viewAll")) { app.selectedTab = 3 }
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.tint)
            }
            VCard(padding: 6) {
                VStack(spacing: 0) {
                    ForEach(Array(vm.district.prefix(3).enumerated()), id: \.element.id) { idx, e in
                        LeaderRow(entry: e)
                        if idx < 2 { Divider().padding(.leading, 44) }
                    }
                }
            }
        }
    }
}

// ── Hero level card ───────────────────────────────────────────────────────────
struct HeroLevelCard: View {
    let me: Me
    let loc: Loc
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.hero, style: .continuous).fill(Theme.hubLevel)
            // decorative circles
            Circle().fill(.white.opacity(0.10)).frame(width: 150).offset(x: 130, y: -60)
            Circle().fill(.white.opacity(0.08)).frame(width: 90).offset(x: -140, y: 55)

            HStack(spacing: 18) {
                LevelRing(progress: me.level.progress, size: 84, lineWidth: 8) {
                    VStack(spacing: -2) {
                        Text("LVL").font(.system(size: 11, weight: .bold)).opacity(0.8)
                        Text("\(me.level.level)").font(.system(size: 30, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(me.title(loc.lang))
                        .font(.system(size: 12, weight: .bold)).opacity(0.92)
                    Text("\(me.points) XP")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                    VProgressBar(value: me.level.progress, height: 9,
                                 fill: AnyShapeStyle(Color.white), track: .white.opacity(0.25))
                    Text("\(me.level.toNext) \(loc.s("xpTo")) \(me.level.level + 1)")
                        .font(.system(size: 12)).opacity(0.85)
                }
                .foregroundStyle(.white)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// ── Quick action tile ─────────────────────────────────────────────────────────
struct QuickActionTile: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(color, in: Circle())
                Text(label).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.tx)
            }
            .frame(maxWidth: .infinity).frame(height: 78)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Theme.card)
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(color.opacity(0.12))
                }
            )
            .vShadowS()
        }
        .buttonStyle(PressStyle())
    }
}

// ── Quest card ────────────────────────────────────────────────────────────────
struct QuestCard: View {
    let quest: Quest
    let loc: Loc
    let onClaim: () -> Void
    private var color: Color { Theme.token(quest.color) }
    private var readyToClaim: Bool { quest.completed && !quest.claimed }

    var body: some View {
        HStack(spacing: 12) {
            IconChip(system: quest.icon, color: color, size: 46, iconSize: 20)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(quest.title(loc.lang)).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.tx)
                    Spacer()
                    Text("+\(quest.rewardXp) XP").font(.system(size: 13, weight: .heavy)).foregroundStyle(color)
                }
                VProgressBar(value: Double(quest.progress) / Double(max(1, quest.target)), height: 7,
                             fill: AnyShapeStyle(color))
                Text("\(quest.progress)/\(quest.target)").font(.system(size: 11)).foregroundStyle(Theme.tx2)
            }
            if quest.claimed {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundStyle(Theme.green)
            } else if readyToClaim {
                Button(loc.s("claim"), action: onClaim)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(color, in: Capsule())
                    .bob(distance: 3, duration: 1.4)
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(readyToClaim ? color : .clear, lineWidth: 2)
        )
        .vShadowS()
    }
}

// ── Badge circle ──────────────────────────────────────────────────────────────
struct BadgeCircle: View {
    let badge: Badge
    var size: CGFloat = 60
    private var color: Color { Theme.token(badge.color) }
    var body: some View {
        ZStack {
            if badge.earned {
                Circle().fill(LinearGradient.angled([color, color.opacity(0.7)], degrees: 150))
                    .shadow(color: color.opacity(0.4), radius: 8, y: 4)
                Image(systemName: badge.icon).font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(.white)
            } else {
                Circle().fill(Theme.card2)
                Image(systemName: "lock.fill").font(.system(size: size * 0.3)).foregroundStyle(Theme.tx3)
            }
        }
        .frame(width: size, height: size)
    }
}

// ── Leaderboard row ───────────────────────────────────────────────────────────
struct LeaderRow: View {
    let entry: LeaderEntry
    var body: some View {
        HStack(spacing: 10) {
            RankMedal(rank: entry.rank ?? 0)
            GradientAvatar(letter: entry.avatarLetter, size: 34,
                           gradient: entry.avatarColor == "avatar" ? Theme.avatar : LinearGradient.angled([Theme.token(entry.avatarColor), Theme.token(entry.avatarColor).opacity(0.7)], degrees: 150))
            Text(entry.isMe ? "\(entry.name)" : entry.name)
                .font(.system(size: 15, weight: entry.isMe ? .bold : .medium))
                .foregroundStyle(Theme.tx)
            Spacer()
            Text("\(entry.xp) XP").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.tx2)
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(entry.isMe ? Theme.tint.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 11))
    }
}
