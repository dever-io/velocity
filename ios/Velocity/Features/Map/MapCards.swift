import SwiftUI
import CoreLocation

// ── Shared helpers ────────────────────────────────────────────────────────────
func uploadURL(_ key: String) -> URL? {
    if key.hasPrefix("http") { return URL(string: key) }
    return URL(string: "http://localhost:8787/uploads/\(key)")
}

func shortDate(_ iso: String?) -> String {
    guard let iso else { return "—" }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    guard let date else { return "—" }
    let out = DateFormatter()
    out.locale = Locale(identifier: "ru_RU")
    out.dateFormat = "d MMM yyyy"
    return out.string(from: date)
}

struct CardHeaderGrabber: View {
    var body: some View { HStack { Spacer(); Grabber(); Spacer() } }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundStyle(Theme.tx2)
            Spacer()
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.tx)
        }
        .padding(.vertical, 9)
    }
}

// ── Segment card ──────────────────────────────────────────────────────────────
struct SegmentCard: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let seg: SegmentFeature

    var body: some View {
        let loc = app.loc
        let p = seg.properties
        VStack(alignment: .leading, spacing: 0) {
            CardHeaderGrabber()
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 5).fill(Theme.infraColor(p.kind)).frame(width: 22, height: 22)
                Text(loc.kind(p.kind)).font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.tx)
            }
            .padding(.top, 6).padding(.bottom, 6)
            if let name = p.name {
                Text(name).font(.system(size: 14)).foregroundStyle(Theme.tx2).padding(.bottom, 6)
            }
            Divider()
            InfoRow(label: loc.s("surface"), value: loc.surf(p.surface)); Divider()
            InfoRow(label: loc.s("quality"), value: loc.s("good")); Divider()
            InfoRow(label: loc.s("source"), value: p.source == "community" ? loc.s("srcCom") : loc.s("srcOsm")); Divider()
            InfoRow(label: loc.s("updated"), value: shortDate(p.updatedAt))
            Spacer(minLength: 12)
            PrimaryButton(title: loc.s("reportHere"), color: Theme.red, icon: "exclamationmark.triangle.fill") {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { app.cover = .report }
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 20)
        .presentationBackground(Theme.bg)
    }
}

// ── POI card ──────────────────────────────────────────────────────────────────
struct POICard: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let poi: POIFeature
    @State private var saved = false

    var body: some View {
        let loc = app.loc
        let p = poi.properties
        VStack(alignment: .leading, spacing: 0) {
            CardHeaderGrabber()
            HStack(spacing: 12) {
                Image(systemName: poiIcon(p.kind)).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(LinearGradient.angled([Theme.poiColor(p.kind), Theme.poiColor(p.kind).opacity(0.7)], degrees: 150), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.name).font(.system(size: 19, weight: .heavy)).foregroundStyle(Theme.tx)
                    Text(loc.poiKind(p.kind)).font(.system(size: 14)).foregroundStyle(Theme.tx2)
                }
                Spacer()
            }
            .padding(.top, 6)
            RoundedRectangle(cornerRadius: 12).fill(LinearGradient.angled([Theme.card2, Theme.poiColor(p.kind).opacity(0.15)], degrees: 120))
                .frame(height: 96).padding(.vertical, 12)
                .overlay(Image(systemName: "photo").font(.system(size: 24)).foregroundStyle(Theme.tx3))
            if let addr = p.details?.address {
                InfoRow(label: loc.s("address"), value: addr)
                Divider()
            }
            Spacer(minLength: 14)
            HStack(spacing: 10) {
                PrimaryButton(title: loc.s("routeHere"), color: Theme.tint, icon: "arrow.triangle.turn.up.right.diamond.fill") {
                    let dest = RoutePoint(name: p.name, lat: poi.coord.latitude, lng: poi.coord.longitude)
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { app.startRoute(to: dest) }
                }
                Button {
                    saved.toggle()
                    Task { _ = try? await APIClient.shared.addFavorite(type: "place", title: p.name) }
                    app.showToast(loc.s("savedRoute"))
                } label: {
                    Image(systemName: saved ? "star.fill" : "star")
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.orange)
                        .frame(width: 52, height: 52)
                        .background(Theme.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 20)
        .presentationBackground(Theme.bg)
    }

    private func poiIcon(_ kind: String) -> String {
        switch kind {
        case "workshop": return "wrench.and.screwdriver.fill"
        case "parking": return "parkingsign"
        case "rental": return "bicycle"
        case "fountain": return "drop.fill"
        default: return "mappin"
        }
    }
}

// ── Report card ───────────────────────────────────────────────────────────────
struct ReportCard: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let rep: ReportFeature
    var onChanged: () -> Void = {}
    @State private var busy = false

    var body: some View {
        let loc = app.loc
        let p = rep.properties
        VStack(alignment: .leading, spacing: 0) {
            CardHeaderGrabber()
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 20)).foregroundStyle(Theme.categoryColor(p.category))
                    .frame(width: 46, height: 46).background(Theme.categoryColor(p.category).opacity(0.15), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text(loc.cat(p.category)).font(.system(size: 19, weight: .heavy)).foregroundStyle(Theme.tx)
                    Text("\(p.reporter ?? "—") · \(shortDate(p.createdAt))").font(.system(size: 13)).foregroundStyle(Theme.tx2)
                }
                Spacer()
            }
            .padding(.top, 6)
            if let comment = p.comment, !comment.isEmpty {
                Text(comment).font(.system(size: 15)).foregroundStyle(Theme.tx).padding(.top, 12)
            }
            if let keys = p.photoKeys, !keys.isEmpty {
                HStack(spacing: 8) {
                    ForEach(keys.prefix(3), id: \.self) { key in
                        AsyncImage(url: uploadURL(key)) { img in img.resizable().scaledToFill() } placeholder: { Theme.card2 }
                            .frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.top, 12)
            }
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 13)).foregroundStyle(Theme.green)
                Text("\(p.confirmations) \(loc.s("confN"))").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.tx2)
            }
            .padding(.top, 12)
            Spacer(minLength: 14)
            HStack(spacing: 10) {
                PrimaryButton(title: loc.s("confirm"), color: Theme.green, icon: "hand.thumbsup.fill") { vote("confirm") }
                Button(loc.s("gone")) { vote("gone") }
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.tx2)
                    .frame(height: 52).padding(.horizontal, 18)
                    .background(Theme.card2, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 20)
        .presentationBackground(Theme.bg)
        .disabled(busy)
    }

    private func vote(_ kind: String) {
        guard let id = rep.id else { return }
        busy = true
        Task {
            let resp = try? await APIClient.shared.vote(reportId: id, kind: kind)
            dismiss()
            onChanged()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if kind == "confirm" {
                    app.handleReward(resp?.reward, toast: "+\(resp?.reward?.delta ?? 2) XP")
                } else {
                    app.showToast(app.loc.s("done"))
                }
            }
        }
    }
}

// ── Layers sheet ──────────────────────────────────────────────────────────────
struct LayersSheet: View {
    @Environment(AppState.self) private var app
    @Binding var toggles: LayerToggles

    var body: some View {
        let loc = app.loc
        VStack(alignment: .leading, spacing: 0) {
            CardHeaderGrabber()
            Text(loc.s("layersTitle")).font(.system(size: 22, weight: .heavy)).padding(.vertical, 10)
            toggleRow(loc.s("lInfra"), $toggles.infra)
            toggleRow(loc.s("lMtb"), $toggles.mtb)
            toggleRow(loc.s("lPoi"), $toggles.poi)
            toggleRow(loc.s("lReports"), $toggles.reports)
            Text(loc.s("legend")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.tx2)
                .padding(.top, 18).padding(.bottom, 8)
            legend
            Spacer()
        }
        .padding(.horizontal, 20).padding(.bottom, 20)
        .presentationBackground(Theme.bg)
    }

    private func toggleRow(_ title: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) { Text(title).font(.system(size: 16)).foregroundStyle(Theme.tx) }
            .tint(Theme.green)
            .padding(.vertical, 6)
    }

    private var legend: some View {
        let items: [(String, String)] = [("prot", "kind_prot"), ("lane", "kind_lane"), ("shared", "kind_shared"), ("mtb", "kind_mtb"), ("other", "kind_other")]
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.0) { kind, key in
                HStack(spacing: 10) {
                    Capsule().fill(Theme.infraColor(kind)).frame(width: 26, height: 5)
                    Text(app.loc.s(key)).font(.system(size: 14)).foregroundStyle(Theme.tx)
                }
            }
        }
    }
}

// ── Search sheet ──────────────────────────────────────────────────────────────
struct SearchSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let onPick: (GeocodeResult) -> Void
    @State private var query = ""
    @State private var results: [GeocodeResult] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        let loc = app.loc
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.tx3)
                    TextField(loc.s("searchPh"), text: $query)
                        .autocorrectionDisabled()
                        .onChange(of: query) { _, q in runSearch(q) }
                    if !query.isEmpty { Button { query = ""; results = [] } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.tx3) } }
                }
                .padding(.horizontal, 14).frame(height: 44)
                .background(Theme.card2, in: RoundedRectangle(cornerRadius: 12))
                .padding(16)

                List {
                    if results.isEmpty {
                        Section(loc.s("recent")) {
                            recentRow("Парк Горького", 37.6035, 55.7295)
                            recentRow("Воробьёвы горы", 37.556, 55.71)
                            recentRow("Лужники", 37.554, 55.7157)
                        }
                    } else {
                        ForEach(results) { r in
                            Button { onPick(r) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.tx)
                                    if let s = r.subtitle { Text(s).font(.system(size: 13)).foregroundStyle(Theme.tx2) }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .background(Theme.bg)
            .navigationTitle(loc.s("searchTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(loc.s("done")) { dismiss() } } }
        }
    }

    private func recentRow(_ name: String, _ lng: Double, _ lat: Double) -> some View {
        Button { onPick(GeocodeResult(name: name, subtitle: "Москва", lng: lng, lat: lat)) } label: {
            HStack { Image(systemName: "clock.arrow.circlepath").foregroundStyle(Theme.tx3); Text(name).foregroundStyle(Theme.tx) }
        }
    }

    private func runSearch(_ q: String) {
        searchTask?.cancel()
        guard q.count >= 2 else { results = []; return }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            let r = (try? await APIClient.shared.geocode(q)) ?? []
            if !Task.isCancelled { results = r }
        }
    }
}
