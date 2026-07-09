import SwiftUI
import CoreLocation

struct DrawFlow: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var points: [CLLocationCoordinate2D] = []
    @State private var showDetails = false
    @State private var kind = "prot"
    @State private var surface = "asphalt"
    @State private var busy = false

    private let kinds = ["prot", "lane", "shared", "mtb", "other"]
    private let surfaces = ["asphalt", "ground", "gravel", "unknown"]

    var body: some View {
        let loc = app.loc
        ZStack {
            MapContainer(
                segments: [], pois: [], reports: [], route: [], me: MapDefaults.center,
                toggles: LayerToggles(), dark: scheme == .dark, recenterTick: 0,
                drawMode: true, drawPoints: points,
                onTapCoordinate: { points.append($0) }
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                banner
                Spacer()
                toolbar
            }

            if showDetails {
                detailsScreen
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showDetails)
    }

    private var banner: some View {
        let loc = app.loc
        return HStack(spacing: 12) {
            IconChip(system: "pencil.and.outline", color: Theme.cProt, size: 40, iconSize: 19)
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.s("drawTitle")).font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.tx)
                Text(points.count >= 2 ? loc.s("drawHint2") : loc.s("drawHint"))
                    .font(.system(size: 12.5)).foregroundStyle(Theme.tx2).lineLimit(2)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.tx2)
                    .frame(width: 30, height: 30).background(Theme.card2, in: Circle())
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .vShadow()
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private var toolbar: some View {
        let loc = app.loc
        return HStack(spacing: 9) {
            Button { if !points.isEmpty { points.removeLast() } } label: {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 19, weight: .semibold)).foregroundStyle(Theme.tx)
                    .frame(width: 46, height: 46).background(Theme.card2, in: RoundedRectangle(cornerRadius: 13))
            }
            Button { points.removeAll() } label: {
                Text(loc.s("clearL")).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.tx2)
                    .frame(height: 46).padding(.horizontal, 15).background(Theme.card2, in: RoundedRectangle(cornerRadius: 13))
            }
            Spacer()
            HStack(spacing: 4) {
                Text("\(points.count)").font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.cProt)
                Text(loc.s("ptsN")).font(.system(size: 13)).foregroundStyle(Theme.tx2)
            }
            Spacer()
            Button { showDetails = true } label: {
                Text(loc.s("drawNext")).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .lineLimit(1).fixedSize()
                    .frame(height: 46).padding(.horizontal, 22)
                    .background(Theme.tint, in: RoundedRectangle(cornerRadius: 13))
                    .opacity(points.count >= 2 ? 1 : 0.4)
            }
            .disabled(points.count < 2)
        }
        .padding(.horizontal, 16).padding(.top, 13)
        .padding(.bottom, 30)
        .background(Theme.card.ignoresSafeArea(edges: .bottom).overlay(alignment: .top) { Rectangle().fill(Theme.sep).frame(height: 0.5) })
    }

    private var detailsScreen: some View {
        let loc = app.loc
        return VStack(spacing: 0) {
            HStack(spacing: 11) {
                Button { showDetails = false } label: {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.tx)
                        .frame(width: 32, height: 32).background(Theme.card2, in: Circle())
                }
                Text(loc.s("drawTitle")).font(.system(size: 21, weight: .heavy)).foregroundStyle(Theme.tx)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(loc.s("drawKindL")).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.tx2)
                    VStack(spacing: 8) {
                        ForEach(kinds, id: \.self) { k in kindRow(k) }
                    }
                    Text(loc.s("drawSurfaceL")).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.tx2)
                    HStack(spacing: 8) {
                        ForEach(surfaces, id: \.self) { s in surfacePill(s) }
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle").foregroundStyle(Theme.tx3)
                        Text(loc.s("reviewNote")).font(.system(size: 13)).foregroundStyle(Theme.tx2)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
            PrimaryButton(title: loc.s("drawSubmit"), color: Theme.green, enabled: !busy) { submit() }
                .padding(16)
        }
        .background(ScreenBackground())
    }

    private func kindRow(_ k: String) -> some View {
        let loc = app.loc
        let selected = kind == k
        return Button { kind = k } label: {
            HStack(spacing: 12) {
                Capsule().fill(Theme.infraColor(k)).frame(width: 28, height: 6)
                Text(loc.kind(k)).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.tx)
                Spacer()
                if selected { Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.infraColor(k)) }
            }
            .padding(.horizontal, 14).frame(height: 50)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(selected ? Theme.infraColor(k) : Theme.sep, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(PressStyle())
    }

    private func surfacePill(_ s: String) -> some View {
        let selected = surface == s
        return Button { surface = s } label: {
            Text(app.loc.surf(s)).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? .white : Theme.tx)
                .padding(.horizontal, 12).frame(height: 36)
                .background(selected ? Theme.tint : Theme.card, in: Capsule())
                .overlay(Capsule().stroke(Theme.sep, lineWidth: selected ? 0 : 1))
        }
    }

    private func submit() {
        busy = true
        let geometry: [String: Any] = ["type": "LineString", "coordinates": points.map { [$0.longitude, $0.latitude] }]
        let payload: [String: Any] = ["kind": kind, "surface": surface]
        Task {
            let resp = try? await APIClient.shared.createEdit(type: "new_segment", geometry: geometry, payload: payload, photoKeys: [])
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                app.handleReward(resp?.reward, toast: app.loc.s("drawSuccess"))
            }
        }
    }
}
