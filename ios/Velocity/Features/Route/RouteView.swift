import SwiftUI
import CoreLocation

struct RouteView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var profile = "city"
    @State private var result: RouteResult?
    @State private var busy = false

    private var destination: RoutePoint {
        app.routeDestination ?? RoutePoint(name: "Парк Горького", lat: 55.7295, lng: 37.6035)
    }
    private var origin: CLLocationCoordinate2D { MapDefaults.center }

    var body: some View {
        let loc = app.loc
        VStack(spacing: 0) {
            FlowNavBar(title: loc.s("routeTitle")) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    endpointsCard
                    profilePicker
                    if let r = result {
                        builtResult(r)
                    } else {
                        emptyState
                    }
                }
                .padding(16)
            }
            PrimaryButton(title: result == nil ? loc.s("build") : loc.s("rebuild"),
                          color: Theme.tint, enabled: !busy) {
                if result == nil { build() } else { result = nil }
            }
            .padding(16)
        }
        .background(ScreenBackground())
    }

    private var endpointsCard: some View {
        let loc = app.loc
        return VCard(padding: 4) {
            VStack(spacing: 0) {
                endpointRow(dot: Theme.green, icon: "location.fill", label: loc.s("from"), value: loc.s("myLoc"))
                Divider().padding(.leading, 44)
                endpointRow(dot: Theme.red, icon: "mappin", label: loc.s("to"), value: destination.name)
            }
        }
    }

    private func endpointRow(dot: Color, icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                .frame(width: 30, height: 30).background(dot, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 12)).foregroundStyle(Theme.tx2)
                Text(value).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.tx)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
    }

    private var profilePicker: some View {
        let loc = app.loc
        return HStack(spacing: 8) {
            profileButton("city", loc.s("profCity"), "building.2.fill")
            profileButton("mtb", loc.s("profMtb"), "mountain.2.fill")
        }
    }

    private func profileButton(_ p: String, _ label: String, _ icon: String) -> some View {
        let selected = profile == p
        return Button { profile = p; result = nil } label: {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(label).font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(selected ? Theme.tx : Theme.tx2)
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(selected ? Theme.card : Theme.card2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(selected ? Theme.sep : .clear, lineWidth: 1))
            .modifier(SelectedShadow(on: selected))
        }
    }

    private var emptyState: some View {
        let loc = app.loc
        return VStack(spacing: 12) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.system(size: 44)).foregroundStyle(Theme.tint.opacity(0.7))
                .padding(.top, 30)
            Text(loc.s("routeHintTitle")).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.tx)
            Text(loc.s("routeHintDesc")).font(.system(size: 14)).foregroundStyle(Theme.tx2)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
    }

    private func builtResult(_ r: RouteResult) -> some View {
        let loc = app.loc
        return VStack(spacing: 16) {
            HStack(spacing: 10) {
                StatTile(value: String(format: "%.1f", Double(r.distance) / 1000), label: "км", color: Theme.tint)
                StatTile(value: "\(Int((Double(r.duration) / 60).rounded()))", label: "мин", color: Theme.green)
                StatTile(value: "\(r.ascent)", label: "м ↑", color: Theme.orange)
            }
            VCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(r.infraPct)% \(loc.s("onInfra"))").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.tx)
                        Spacer()
                    }
                    VProgressBar(value: Double(r.infraPct) / 100, height: 8,
                                 fill: AnyShapeStyle(LinearGradient.angled([Theme.cProt, Theme.green], degrees: 90)))
                }
            }
            VCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc.s("elevation")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.tx)
                    ElevationChart(points: r.elevation).frame(height: 96)
                }
            }
            PrimaryButton(title: loc.s("saveRoute"), color: Theme.green, icon: "star.fill") { save() }
        }
    }

    private func build() {
        busy = true
        Task {
            result = try? await APIClient.shared.route(from: origin, to: destination.coord, profile: profile)
            if profile == "mtb" || profile == "city" {
                try? await APIClient.shared.event(name: "route_built", props: ["profile": profile])
            }
            busy = false
        }
    }

    private func save() {
        Task { _ = try? await APIClient.shared.addFavorite(type: "route", title: "\(app.loc.s("myLoc")) → \(destination.name)") }
        app.showToast(app.loc.s("savedRoute"))
        dismiss()
    }
}

private struct SelectedShadow: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View { on ? AnyView(content.vShadowS()) : AnyView(content) }
}

// Elevation area chart
struct ElevationChart: View {
    let points: [ElevationPoint]
    var body: some View {
        Canvas { ctx, size in
            guard points.count >= 2 else { return }
            let w = size.width, h = size.height
            let eles = points.map { Double($0.ele) }
            let minE = (eles.min() ?? 0) - 2
            let maxE = (eles.max() ?? 1) + 2
            let maxD = Double(points.last?.d ?? 1)
            func pt(_ p: ElevationPoint) -> CGPoint {
                let x = maxD > 0 ? CGFloat(Double(p.d) / maxD) * w : 0
                let y = h - CGFloat((Double(p.ele) - minE) / max(1, maxE - minE)) * h
                return CGPoint(x: x, y: y)
            }
            var area = Path()
            area.move(to: CGPoint(x: 0, y: h))
            for e in points { area.addLine(to: pt(e)) }
            area.addLine(to: CGPoint(x: w, y: h)); area.closeSubpath()
            ctx.fill(area, with: .linearGradient(
                Gradient(colors: [Theme.tint.opacity(0.35), Theme.tint.opacity(0.02)]),
                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)))
            var line = Path()
            line.move(to: pt(points[0]))
            for e in points.dropFirst() { line.addLine(to: pt(e)) }
            ctx.stroke(line, with: .color(Theme.tint), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }
}
