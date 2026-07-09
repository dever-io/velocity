import SwiftUI
import CoreLocation

@MainActor
@Observable
final class MapVM {
    var segments: [SegmentFeature] = []
    var pois: [POIFeature] = []
    var reports: [ReportFeature] = []
    var toggles = LayerToggles()
    var selection: MapSelection?
    var showLayers = false
    var showSearch = false
    var recenterTick = 0
    var focus: CLLocationCoordinate2D?
    var focusTick = 0
    private var loadTask: Task<Void, Never>?

    func load(_ box: MKBox) {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            async let s = try? APIClient.shared.segments(bbox: box, kinds: [])
            async let p = try? APIClient.shared.pois(bbox: box, kinds: [])
            async let r = try? APIClient.shared.reports(bbox: box)
            let (ss, pp, rr) = await (s, p, r)
            guard let self, !Task.isCancelled else { return }
            if let ss { self.segments = ss }
            if let pp { self.pois = pp }
            if let rr { self.reports = rr }
        }
    }

    func reloadCurrent() { load(MKBox(minLon: 37.5, minLat: 55.68, maxLon: 37.66, maxLat: 55.77)) }
}

struct MapScreen: View {
    @Environment(AppState.self) private var app
    @Environment(\.colorScheme) private var scheme
    @State private var vm = MapVM()
    @State private var loc = LocationProvider()
    @State private var centeredOnMe = false

    var body: some View {
        @Bindable var vm = vm
        ZStack(alignment: .top) {
            MapContainer(
                segments: vm.segments, pois: vm.pois, reports: vm.reports,
                route: [], me: loc.coordinate ?? MapDefaults.center, toggles: vm.toggles,
                dark: scheme == .dark, recenterTick: vm.recenterTick,
                focus: vm.focus, focusTick: vm.focusTick,
                onSelect: { vm.selection = $0 },
                onRegion: { vm.load($0) }
            )
            .ignoresSafeArea()
            .onChange(of: loc.coordinate?.latitude) { _, lat in
                if lat != nil && !centeredOnMe { centeredOnMe = true; vm.recenterTick += 1 }
            }

            FogOfWar().allowsHitTesting(false)

            chrome
            districtPill

            // Mandatory OSM attribution (spec SET-2)
            VStack {
                Spacer()
                Text(app.loc.s("osmAttribution"))
                    .font(.system(size: 9)).foregroundStyle(Theme.tx2)
                    .padding(.bottom, 92)
            }
            .allowsHitTesting(false)
        }
        .sheet(item: $vm.selection) { sel in
            Group {
                switch sel {
                case .segment(let s): SegmentCard(seg: s)
                case .poi(let p): POICard(poi: p)
                case .report(let r): ReportCard(rep: r) { vm.reloadCurrent() }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $vm.showLayers) {
            LayersSheet(toggles: $vm.toggles)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $vm.showSearch) {
            SearchSheet { result in
                vm.focus = result.coord
                vm.focusTick += 1
                vm.showSearch = false
            }
        }
        .task {
            loc.start()
            vm.reloadCurrent()
            if let ca = app.cardArg {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                switch ca {
                case "segment": if let s = vm.segments.first { vm.selection = .segment(s) }
                case "poi": if let p = vm.pois.first { vm.selection = .poi(p) }
                case "report": if let r = vm.reports.first { vm.selection = .report(r) }
                default: break
                }
            }
        }
    }

    private var chrome: some View {
        let loc = app.loc
        return VStack {
            HStack(spacing: 10) {
                Button { vm.showSearch = true } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.tx3)
                        Text(loc.s("searchPh")).font(.system(size: 15)).foregroundStyle(Theme.tx3)
                        Spacer()
                    }
                    .padding(.horizontal, 15).frame(height: 44)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .vShadow()
                }
                Button { app.selectedTab = 4 } label: {
                    GradientAvatar(letter: app.me?.avatarLetter ?? "V", size: 44, gradient: Theme.avatar)
                        .background(Theme.card, in: Circle())
                        .vShadow()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
    }

    private var districtPill: some View {
        let loc = app.loc
        return VStack {
            Spacer()
            HStack(alignment: .bottom) {
                VCard(padding: 12, radius: 15) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Image(systemName: "flag.fill").font(.system(size: 13)).foregroundStyle(Theme.cProt)
                            Text(app.me?.districtName(loc.lang) ?? "").font(.system(size: 13.5, weight: .heavy)).foregroundStyle(Theme.tx)
                            Spacer()
                            Text("68%").font(.system(size: 13.5, weight: .heavy)).foregroundStyle(Theme.cProt)
                        }
                        VProgressBar(value: 0.68, height: 7, fill: AnyShapeStyle(LinearGradient.angled([Theme.cProt, Theme.green], degrees: 90)))
                        Text(loc.s("conquerNote")).font(.system(size: 11)).foregroundStyle(Theme.tx2)
                    }
                }
                .frame(width: 210)

                Spacer()

                VStack(spacing: 11) {
                    MapToolButton(icon: "square.3.layers.3d") { vm.showLayers = true }
                    MapToolButton(icon: "location.fill") { vm.recenterTick += 1 }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
    }
}

struct MapToolButton: View {
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.tint)
                .frame(width: 46, height: 46)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .vShadow()
        }
    }
}

// Gamey "uncharted" corners
struct FogOfWar: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                blob.position(x: geo.size.width * 0.12, y: geo.size.height * 0.30)
                blob.position(x: geo.size.width * 0.9, y: geo.size.height * 0.72)
            }
        }
    }
    private var blob: some View {
        ZStack {
            Circle().fill(Color(red: 0.41, green: 0.42, blue: 0.51).opacity(0.30)).frame(width: 150)
            Text("?").font(.system(size: 22, weight: .heavy)).foregroundStyle(.white.opacity(0.7))
        }
        .blur(radius: 0.5)
    }
}
