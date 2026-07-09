import SwiftUI
import CoreLocation
import MapLibre

struct LayerToggles: Equatable {
    var infra = true
    var mtb = true
    var poi = true
    var reports = true
}

enum MapSelection: Identifiable {
    case segment(SegmentFeature)
    case poi(POIFeature)
    case report(ReportFeature)
    var id: String {
        switch self {
        case .segment(let s): return "s-\(s.id ?? "")"
        case .poi(let p): return "p-\(p.id ?? "")"
        case .report(let r): return "r-\(r.id ?? "")"
        }
    }
}

struct MapContainer: UIViewRepresentable {
    var segments: [SegmentFeature]
    var pois: [POIFeature]
    var reports: [ReportFeature]
    var route: [CLLocationCoordinate2D]
    var me: CLLocationCoordinate2D?
    var toggles: LayerToggles
    var dark: Bool
    var recenterTick: Int
    var focus: CLLocationCoordinate2D? = nil
    var focusTick: Int = 0
    var drawMode: Bool = false
    var drawPoints: [CLLocationCoordinate2D] = []
    var fitRoute: Bool = false
    var onSelect: (MapSelection) -> Void = { _ in }
    var onRegion: (MKBox) -> Void = { _ in }
    var onTapCoordinate: (CLLocationCoordinate2D) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero)
        map.delegate = context.coordinator
        // Real street basemap (OpenFreeMap). If it can't load (e.g. blocked in a
        // sandboxed simulator), the delegate falls back to a self-contained offline
        // style. Either way our GeoJSON layers render on top.
        map.styleURL = mapStyleURL(dark: dark)
        context.coordinator.lastDark = dark
        map.setCenter(MapDefaults.center, zoomLevel: 13.5, animated: false)
        map.logoView.isHidden = true
        map.attributionButton.tintColor = UIColor.gray
        map.tintColor = UIColor(Theme.tint)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        map.addGestureRecognizer(tap)
        context.coordinator.mapView = map
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        let c = context.coordinator
        c.parent = self
        if c.lastDark != dark {
            c.lastDark = dark
            c.triedFallback = false
            map.styleURL = mapStyleURL(dark: dark) // re-theme (re-fires didFinishLoading)
        }
        c.apply(segments: segments, pois: pois, reports: reports, route: route, me: me, toggles: toggles)
        if c.lastRecenter != recenterTick {
            c.lastRecenter = recenterTick
            map.setCenter(me ?? MapDefaults.center, zoomLevel: 14, animated: true)
        }
        if c.lastFocus != focusTick, let focus {
            c.lastFocus = focusTick
            map.setCenter(focus, zoomLevel: 15, animated: true)
        }
        if fitRoute, route.count >= 2, c.lastFitCount != route.count {
            c.lastFitCount = route.count
            var minLat = 90.0, minLon = 180.0, maxLat = -90.0, maxLon = -180.0
            for co in route {
                minLat = min(minLat, co.latitude); maxLat = max(maxLat, co.latitude)
                minLon = min(minLon, co.longitude); maxLon = max(maxLon, co.longitude)
            }
            let bounds = MLNCoordinateBounds(
                sw: CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
                ne: CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon))
            map.setVisibleCoordinateBounds(bounds, edgePadding: UIEdgeInsets(top: 34, left: 34, bottom: 34, right: 34), animated: false)
        }
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: MapContainer
        weak var mapView: MLNMapView?
        var lastRecenter = 0
        var lastFocus = 0
        var lastFitCount = -1
        var lastDark = false
        var triedFallback = false
        var usingOffline = false
        private var styleReady = false
        private var decorSource: MLNShapeSource?
        private var segById: [String: SegmentFeature] = [:]
        private var poiById: [String: POIFeature] = [:]
        private var repById: [String: ReportFeature] = [:]

        private var segSource: MLNShapeSource?
        private var poiSource: MLNShapeSource?
        private var repSource: MLNShapeSource?
        private var routeSource: MLNShapeSource?
        private var meSource: MLNShapeSource?
        private var drawSource: MLNShapeSource?

        private let segKinds = ["prot", "lane", "shared", "mtb", "other"]
        private let poiKinds = ["workshop", "parking", "rental", "fountain"]

        // Approximate local basemap geometry (Khamovniki / Gorky Park area)
        static let parks: [[CLLocationCoordinate2D]] = [
            [.init(latitude: 55.717, longitude: 37.596), .init(latitude: 55.719, longitude: 37.612), .init(latitude: 55.731, longitude: 37.609), .init(latitude: 55.729, longitude: 37.597)],
            [.init(latitude: 55.713, longitude: 37.549), .init(latitude: 55.714, longitude: 37.560), .init(latitude: 55.722, longitude: 37.559), .init(latitude: 55.721, longitude: 37.548)],
            [.init(latitude: 55.740, longitude: 37.585), .init(latitude: 55.741, longitude: 37.593), .init(latitude: 55.746, longitude: 37.592), .init(latitude: 55.745, longitude: 37.584)],
        ]
        static let river: [CLLocationCoordinate2D] = [
            .init(latitude: 55.733, longitude: 37.545), .init(latitude: 55.727, longitude: 37.560),
            .init(latitude: 55.723, longitude: 37.575), .init(latitude: 55.723, longitude: 37.590),
            .init(latitude: 55.727, longitude: 37.603), .init(latitude: 55.735, longitude: 37.612),
            .init(latitude: 55.744, longitude: 37.618),
        ]

        init(_ parent: MapContainer) { self.parent = parent }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            setupImages(style)
            setupSources(style)
            setupLayers(style)
            styleReady = true
            applyPending()
        }

        func mapViewDidFailLoadingMap(_ mapView: MLNMapView, withError error: Error) {
            // OpenFreeMap unreachable → fall back to the self-contained offline style.
            if !triedFallback {
                triedFallback = true
                usingOffline = true
                mapView.styleURL = localStyleURL(dark: parent.dark)
            }
        }

        // Register report triangle images
        private func setupImages(_ style: MLNStyle) {
            style.setImage(triangle(color: UIColor(Theme.red)), forName: "tri-red")
            style.setImage(triangle(color: UIColor(Theme.orange)), forName: "tri-orange")
        }

        private func setupSources(_ style: MLNStyle) {
            let empty = MLNShapeCollectionFeature(shapes: [])
            decorSource = MLNShapeSource(identifier: "decor", shape: decorShape(), options: nil)
            segSource = MLNShapeSource(identifier: "seg", shape: empty, options: nil)
            poiSource = MLNShapeSource(identifier: "poi", shape: empty, options: nil)
            repSource = MLNShapeSource(identifier: "rep", shape: empty, options: nil)
            routeSource = MLNShapeSource(identifier: "route", shape: empty, options: nil)
            meSource = MLNShapeSource(identifier: "me", shape: empty, options: nil)
            drawSource = MLNShapeSource(identifier: "draw", shape: empty, options: nil)
            [decorSource, segSource, poiSource, repSource, routeSource, meSource, drawSource].compactMap { $0 }.forEach { style.addSource($0) }
        }

        private func decorShape() -> MLNShape {
            var shapes: [MLNShape] = []
            for poly in Self.parks {
                let f = MLNPolygonFeature(coordinates: poly, count: UInt(poly.count))
                f.attributes = ["t": "park"]
                shapes.append(f)
            }
            let r = MLNPolylineFeature(coordinates: Self.river, count: UInt(Self.river.count))
            r.attributes = ["t": "river"]
            shapes.append(r)
            return MLNShapeCollectionFeature(shapes: shapes)
        }

        private func setupLayers(_ style: MLNStyle) {
            guard let segSource, let poiSource, let repSource, let routeSource, let meSource, let decorSource, let drawSource else { return }

            // Decorative parks + river — only for the offline style (the real
            // OpenFreeMap basemap already draws its own parks and water).
            if usingOffline {
                let park = MLNFillStyleLayer(identifier: "decor-park", source: decorSource)
                park.predicate = NSPredicate(format: "t == %@", "park")
                park.fillColor = NSExpression(forConstantValue: UIColor(parent.dark ? Color(hex: 0x1F3324) : Color(hex: 0xD3E5C4)))
                style.addLayer(park)
                let river = MLNLineStyleLayer(identifier: "decor-river", source: decorSource)
                river.predicate = NSPredicate(format: "t == %@", "river")
                river.lineColor = NSExpression(forConstantValue: UIColor(parent.dark ? Color(hex: 0x123047) : Color(hex: 0xAAD3F2)))
                river.lineWidth = NSExpression(forConstantValue: 18)
                river.lineCap = NSExpression(forConstantValue: "round")
                river.lineJoin = NSExpression(forConstantValue: "round")
                style.addLayer(river)
            }

            // Route underlay + line
            let routeUnder = MLNLineStyleLayer(identifier: "route-under", source: routeSource)
            routeUnder.lineColor = NSExpression(forConstantValue: UIColor(Theme.tint).withAlphaComponent(0.28))
            routeUnder.lineWidth = NSExpression(forConstantValue: 10)
            routeUnder.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(routeUnder)
            let routeLine = MLNLineStyleLayer(identifier: "route-line", source: routeSource)
            routeLine.lineColor = NSExpression(forConstantValue: UIColor(Theme.tint))
            routeLine.lineWidth = NSExpression(forConstantValue: 4.5)
            routeLine.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(routeLine)

            // Infra segments — one layer per kind
            for kind in segKinds {
                let layer = MLNLineStyleLayer(identifier: "seg-\(kind)", source: segSource)
                layer.predicate = NSPredicate(format: "kind == %@", kind)
                layer.lineColor = NSExpression(forConstantValue: UIColor(Theme.infraColor(kind)))
                layer.lineWidth = NSExpression(forConstantValue: 5)
                layer.lineCap = NSExpression(forConstantValue: "round")
                layer.lineJoin = NSExpression(forConstantValue: "round")
                if kind == "shared" { layer.lineDashPattern = NSExpression(forConstantValue: [2.2, 1.8]) }
                if kind == "mtb" { layer.lineDashPattern = NSExpression(forConstantValue: [0.6, 2]) }
                style.addLayer(layer)
            }

            // POIs — circle per kind
            for kind in poiKinds {
                let layer = MLNCircleStyleLayer(identifier: "poi-\(kind)", source: poiSource)
                layer.predicate = NSPredicate(format: "kind == %@", kind)
                layer.circleColor = NSExpression(forConstantValue: UIColor(Theme.poiColor(kind)))
                layer.circleRadius = NSExpression(forConstantValue: 6)
                layer.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
                layer.circleStrokeWidth = NSExpression(forConstantValue: 2.5)
                style.addLayer(layer)
            }

            // Reports — triangle symbols
            let repRed = MLNSymbolStyleLayer(identifier: "rep-red", source: repSource)
            repRed.predicate = NSPredicate(format: "category IN %@", ["pothole", "hazard", "other"])
            repRed.iconImageName = NSExpression(forConstantValue: "tri-red")
            repRed.iconAllowsOverlap = NSExpression(forConstantValue: true)
            style.addLayer(repRed)
            let repOrange = MLNSymbolStyleLayer(identifier: "rep-orange", source: repSource)
            repOrange.predicate = NSPredicate(format: "category IN %@", ["closure", "glass"])
            repOrange.iconImageName = NSExpression(forConstantValue: "tri-orange")
            repOrange.iconAllowsOverlap = NSExpression(forConstantValue: true)
            style.addLayer(repOrange)

            // Draw-a-lane: dashed line + point handles
            let drawLine = MLNLineStyleLayer(identifier: "draw-line", source: drawSource)
            drawLine.lineColor = NSExpression(forConstantValue: UIColor(Theme.cProt))
            drawLine.lineWidth = NSExpression(forConstantValue: 5)
            drawLine.lineDashPattern = NSExpression(forConstantValue: [0.5, 1.5])
            drawLine.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(drawLine)
            let drawPts = MLNCircleStyleLayer(identifier: "draw-pts", source: drawSource)
            drawPts.predicate = NSPredicate(format: "kind == %@", "pt")
            drawPts.circleColor = NSExpression(forConstantValue: UIColor.white)
            drawPts.circleRadius = NSExpression(forConstantValue: 7)
            drawPts.circleStrokeColor = NSExpression(forConstantValue: UIColor(Theme.cProt))
            drawPts.circleStrokeWidth = NSExpression(forConstantValue: 3.5)
            style.addLayer(drawPts)

            // Me — halo + dot
            let halo = MLNCircleStyleLayer(identifier: "me-halo", source: meSource)
            halo.circleColor = NSExpression(forConstantValue: UIColor(Theme.tint).withAlphaComponent(0.25))
            halo.circleRadius = NSExpression(forConstantValue: 18)
            style.addLayer(halo)
            let dot = MLNCircleStyleLayer(identifier: "me-dot", source: meSource)
            dot.circleColor = NSExpression(forConstantValue: UIColor(Theme.tint))
            dot.circleRadius = NSExpression(forConstantValue: 7)
            dot.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
            dot.circleStrokeWidth = NSExpression(forConstantValue: 3)
            style.addLayer(dot)
        }

        // Pending application before style loads
        private var pending: (seg: [SegmentFeature], poi: [POIFeature], rep: [ReportFeature], route: [CLLocationCoordinate2D], me: CLLocationCoordinate2D?, toggles: LayerToggles)?

        func apply(segments: [SegmentFeature], pois: [POIFeature], reports: [ReportFeature], route: [CLLocationCoordinate2D], me: CLLocationCoordinate2D?, toggles: LayerToggles) {
            guard styleReady, let style = mapView?.style else {
                pending = (segments, pois, reports, route, me, toggles)
                return
            }
            segById = Dictionary(uniqueKeysWithValues: segments.compactMap { s in s.id.map { ($0, s) } })
            poiById = Dictionary(uniqueKeysWithValues: pois.compactMap { p in p.id.map { ($0, p) } })
            repById = Dictionary(uniqueKeysWithValues: reports.compactMap { r in r.id.map { ($0, r) } })

            segSource?.shape = MLNShapeCollectionFeature(shapes: segments.map { s in
                let line = MLNPolylineFeature(coordinates: s.coords, count: UInt(s.coords.count))
                line.attributes = ["kind": s.properties.kind, "id": s.id ?? "", "ftype": "segment"]
                return line
            })
            poiSource?.shape = MLNShapeCollectionFeature(shapes: pois.map { p in
                let pt = MLNPointFeature()
                pt.coordinate = p.coord
                pt.attributes = ["kind": p.properties.kind, "id": p.id ?? "", "ftype": "poi"]
                return pt
            })
            repSource?.shape = MLNShapeCollectionFeature(shapes: reports.map { r in
                let pt = MLNPointFeature()
                pt.coordinate = r.coord
                pt.attributes = ["category": r.properties.category, "id": r.id ?? "", "ftype": "report"]
                return pt
            })
            if route.count >= 2 {
                routeSource?.shape = MLNPolylineFeature(coordinates: route, count: UInt(route.count))
            } else {
                routeSource?.shape = MLNShapeCollectionFeature(shapes: [])
            }
            if let me {
                let pt = MLNPointFeature(); pt.coordinate = me
                meSource?.shape = pt
            }

            // Draw shapes (line + handles) from parent.drawPoints
            let dp = parent.drawPoints
            var drawShapes: [MLNShape] = []
            if dp.count >= 2 {
                drawShapes.append(MLNPolylineFeature(coordinates: dp, count: UInt(dp.count)))
            }
            for c in dp {
                let f = MLNPointFeature(); f.coordinate = c; f.attributes = ["kind": "pt"]
                drawShapes.append(f)
            }
            drawSource?.shape = MLNShapeCollectionFeature(shapes: drawShapes)

            // Toggles
            setVisible(style, "seg-prot", toggles.infra)
            setVisible(style, "seg-lane", toggles.infra)
            setVisible(style, "seg-shared", toggles.infra)
            setVisible(style, "seg-other", toggles.infra)
            setVisible(style, "seg-mtb", toggles.infra && toggles.mtb)
            for k in poiKinds { setVisible(style, "poi-\(k)", toggles.poi) }
            setVisible(style, "rep-red", toggles.reports)
            setVisible(style, "rep-orange", toggles.reports)
        }

        private func applyPending() {
            guard let p = pending else { return }
            pending = nil
            apply(segments: p.seg, pois: p.poi, reports: p.rep, route: p.route, me: p.me, toggles: p.toggles)
        }

        private func setVisible(_ style: MLNStyle, _ id: String, _ visible: Bool) {
            style.layer(withIdentifier: id)?.isVisible = visible
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            let b = mapView.visibleCoordinateBounds
            parent.onRegion(MKBox(minLon: b.sw.longitude, minLat: b.sw.latitude, maxLon: b.ne.longitude, maxLat: b.ne.latitude))
        }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard let map = mapView else { return }
            let pt = g.location(in: map)
            if parent.drawMode {
                parent.onTapCoordinate(map.convert(pt, toCoordinateFrom: map))
                return
            }
            let rect = CGRect(x: pt.x - 12, y: pt.y - 12, width: 24, height: 24)
            let ids: Set<String> = ["seg-prot", "seg-lane", "seg-shared", "seg-mtb", "seg-other", "poi-workshop", "poi-parking", "poi-rental", "poi-fountain", "rep-red", "rep-orange"]
            let feats = map.visibleFeatures(in: rect, styleLayerIdentifiers: ids)
            guard let f = feats.first,
                  let ftype = f.attribute(forKey: "ftype") as? String,
                  let id = f.attribute(forKey: "id") as? String else { return }
            switch ftype {
            case "segment": if let s = segById[id] { parent.onSelect(.segment(s)) }
            case "poi": if let p = poiById[id] { parent.onSelect(.poi(p)) }
            case "report": if let r = repById[id] { parent.onSelect(.report(r)) }
            default: break
            }
        }
    }
}

// Real street basemap from OpenFreeMap (keyless). Reachable on a device with
// internet; the delegate falls back to localStyleURL when it can't load.
func mapStyleURL(dark: Bool) -> URL {
    URL(string: "https://tiles.openfreemap.org/styles/liberty")!
}

// Offline base style: a themed land background. Written to a temp file and used
// as the map's styleURL (no external tile hosts required).
func localStyleURL(dark: Bool) -> URL {
    let land = dark ? "#20242B" : "#E9E7DF"
    let json = """
    {"version":8,"name":"velo-local","sources":{},\
    "layers":[{"id":"bg","type":"background","paint":{"background-color":"\(land)"}}]}
    """
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("velo-style-\(dark ? "d" : "l").json")
    try? json.data(using: .utf8)?.write(to: url)
    return url
}

// Report triangle marker image
func triangle(color: UIColor) -> UIImage {
    let size = CGSize(width: 26, height: 24)
    return UIGraphicsImageRenderer(size: size).image { _ in
        let p = UIBezierPath()
        p.move(to: CGPoint(x: 13, y: 1))
        p.addLine(to: CGPoint(x: 25, y: 22))
        p.addLine(to: CGPoint(x: 1, y: 22))
        p.close()
        color.setFill(); p.fill()
        UIColor.white.setStroke(); p.lineWidth = 2.2; p.stroke()
        UIColor.white.setFill()
        UIBezierPath(roundedRect: CGRect(x: 11.7, y: 8, width: 2.6, height: 7), cornerRadius: 1.3).fill()
        UIBezierPath(ovalIn: CGRect(x: 11.5, y: 16.5, width: 3, height: 3)).fill()
    }
}
