import SwiftUI

enum ContribFilter { case reports, edits }

struct ContributionsView: View {
    let filter: ContribFilter
    @Environment(AppState.self) private var app
    @State private var data: Contributions?

    var body: some View {
        let loc = app.loc
        List {
            if let d = data {
                Section(loc.s("history")) {
                    ForEach(d.history) { h in
                        HStack {
                            Text(loc.reason(h.reason)).font(.system(size: 15)).foregroundStyle(Theme.tx)
                            Spacer()
                            Text("+\(h.delta)").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.green)
                            Text(shortDate(h.createdAt)).font(.system(size: 12)).foregroundStyle(Theme.tx3)
                        }
                    }
                }
                if filter == .reports {
                    Section(loc.s("myReports")) {
                        ForEach(d.reports) { r in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(loc.cat(r.category)).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.tx)
                                    Spacer()
                                    StatusPill(status: r.status, loc: loc)
                                }
                                if let c = r.comment, !c.isEmpty { Text(c).font(.system(size: 13)).foregroundStyle(Theme.tx2) }
                            }
                        }
                    }
                } else {
                    Section(loc.s("myEdits")) {
                        ForEach(d.edits) { e in
                            HStack {
                                Image(systemName: e.type.contains("poi") ? "mappin.circle.fill" : "pencil.and.outline").foregroundStyle(Theme.green)
                                Text(loc.kind(payloadKindFallback(e.type))).font(.system(size: 15)).foregroundStyle(Theme.tx)
                                Spacer()
                                if e.awarded > 0 { Text("+\(e.awarded)").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.green) }
                                StatusPill(status: e.status, loc: loc)
                            }
                        }
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(filter == .reports ? loc.s("myReports") : loc.s("myEdits"))
        .navigationBarTitleDisplayMode(.inline)
        .task { data = try? await APIClient.shared.contributions() }
    }

    private func payloadKindFallback(_ type: String) -> String {
        type.contains("poi") ? "other" : "lane"
    }
}

struct StatusPill: View {
    let status: String
    let loc: Loc
    var body: some View {
        let (text, color): (String, Color) = {
            switch status {
            case "approved", "active": return (loc.lang == .ru ? "принято" : "accepted", Theme.green)
            case "pending": return (loc.lang == .ru ? "на модерации" : "pending", Theme.orange)
            case "rejected": return (loc.lang == .ru ? "отклонено" : "rejected", Theme.red)
            default: return (status, Theme.tx3)
            }
        }()
        return Text(text).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }
}

struct FavoritesView: View {
    @Environment(AppState.self) private var app
    @State private var favs: [Favorite] = []

    var body: some View {
        let loc = app.loc
        List {
            ForEach(favs) { f in
                HStack(spacing: 12) {
                    Image(systemName: f.type == "route" ? "point.topleft.down.to.point.bottomright.curvepath" : "mappin.circle.fill")
                        .foregroundStyle(f.type == "route" ? Theme.tint : Theme.orange)
                    Text(f.title).font(.system(size: 16)).foregroundStyle(Theme.tx)
                }
            }
            .onDelete { idx in
                for i in idx { let id = favs[i].id; Task { try? await APIClient.shared.deleteFavorite(id) } }
                favs.remove(atOffsets: idx)
            }
            if favs.isEmpty { Text("—").foregroundStyle(Theme.tx3) }
        }
        .navigationTitle(loc.s("favorites"))
        .navigationBarTitleDisplayMode(.inline)
        .task { favs = (try? await APIClient.shared.favorites()) ?? [] }
    }
}
