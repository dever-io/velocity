import Foundation
import CoreLocation

struct APIError: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
}

struct Ack: Codable {}

final class APIClient {
    static let shared = APIClient()

    // Local backend. The simulator shares the Mac's network (localhost); a physical
    // device must reach the Mac by its LAN IP (same Wi-Fi). Override via the
    // Info.plist key "APIBaseURL" if the Mac's IP changes.
    #if targetEnvironment(simulator)
    var baseURL = URL(string: "http://localhost:8787")!
    #else
    var baseURL = URL(string: (Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String) ?? "http://192.168.1.11:8787")!
    #endif
    var token: String?

    private let decoder = JSONDecoder()

    // MARK: core
    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        body: [String: Any]? = nil,
        auth: Bool = true
    ) async throws -> T {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.timeoutInterval = 20
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.setValue("application/json", forHTTPHeaderField: "content-type")
        }
        if auth, let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "authorization") }

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError(status: 0, message: "No response") }
        guard 200..<300 ~= http.statusCode else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw APIError(status: http.statusCode, message: msg ?? "HTTP \(http.statusCode)")
        }
        if T.self == Ack.self { return Ack() as! T }
        return try decoder.decode(T.self, from: data)
    }

    private func bboxItem(_ b: MKBox) -> URLQueryItem {
        URLQueryItem(name: "bbox", value: "\(b.minLon),\(b.minLat),\(b.maxLon),\(b.maxLat)")
    }

    // MARK: auth / account
    func authDev(sub: String = "dev-anya", name: String = "Аня В.", letter: String = "А", locale: String = "ru") async throws -> AuthResponse {
        try await request("auth/dev", method: "POST", body: ["sub": sub, "name": name, "letter": letter, "locale": locale], auth: false)
    }
    func me() async throws -> Me { try await request("me") }
    func patchMe(_ fields: [String: Any]) async throws -> Me { try await request("me", method: "PATCH", body: fields) }
    func deleteMe() async throws { let _: Ack = try await request("me", method: "DELETE") }
    func contributions() async throws -> Contributions { try await request("me/contributions") }

    // MARK: map
    func segments(bbox: MKBox, kinds: [String]) async throws -> [SegmentFeature] {
        var q = [bboxItem(bbox)]
        if !kinds.isEmpty { q.append(URLQueryItem(name: "kinds", value: kinds.joined(separator: ","))) }
        let fc: FC<SegmentFeature> = try await request("map/segments", query: q, auth: false)
        return fc.features
    }
    func pois(bbox: MKBox, kinds: [String]) async throws -> [POIFeature] {
        var q = [bboxItem(bbox)]
        if !kinds.isEmpty { q.append(URLQueryItem(name: "kinds", value: kinds.joined(separator: ","))) }
        let fc: FC<POIFeature> = try await request("map/pois", query: q, auth: false)
        return fc.features
    }
    func reports(bbox: MKBox) async throws -> [ReportFeature] {
        let fc: FC<ReportFeature> = try await request("map/reports", query: [bboxItem(bbox)], auth: false)
        return fc.features
    }

    // MARK: community
    func createReport(category: String, comment: String?, coord: CLLocationCoordinate2D, photoKeys: [String]) async throws -> CreateReportResponse {
        try await request("reports", method: "POST", body: [
            "category": category, "comment": comment ?? "", "lng": coord.longitude, "lat": coord.latitude, "photoKeys": photoKeys,
        ])
    }
    func vote(reportId: String, kind: String) async throws -> VoteResponse {
        try await request("reports/\(reportId)/vote", method: "POST", body: ["kind": kind])
    }
    func createEdit(type: String, geometry: [String: Any]?, payload: [String: Any], photoKeys: [String]) async throws -> EditResponse {
        var body: [String: Any] = ["type": type, "payload": payload, "photoKeys": photoKeys]
        if let geometry { body["geometry"] = geometry }
        return try await request("edits", method: "POST", body: body)
    }

    // MARK: routing / geocode
    func route(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, profile: String) async throws -> RouteResult {
        try await request("route", method: "POST", body: [
            "from": ["lng": from.longitude, "lat": from.latitude],
            "to": ["lng": to.longitude, "lat": to.latitude],
            "profile": profile,
        ])
    }
    func geocode(_ q: String) async throws -> [GeocodeResult] {
        let r: GeocodeResponse = try await request("geocode", query: [URLQueryItem(name: "q", value: q)])
        return r.results
    }

    // MARK: gamification
    func quests() async throws -> [Quest] { try await request("quests") }
    func claimQuest(_ id: String) async throws -> QuestClaimResponse { try await request("quests/\(id)/claim", method: "POST") }
    func badges() async throws -> BadgesResponse { try await request("badges") }
    func leaderboard(board: String) async throws -> LeaderboardResponse {
        try await request("leaderboard", query: [URLQueryItem(name: "board", value: board)])
    }
    func league() async throws -> LeagueResponse { try await request("league") }
    func season() async throws -> SeasonResponse { try await request("season") }
    func event(name: String, props: [String: Any] = [:]) async throws {
        let _: Ack = try await request("events", method: "POST", body: ["name": name, "props": props])
    }

    // MARK: favorites
    func favorites() async throws -> [Favorite] { try await request("favorites") }
    func addFavorite(type: String, title: String, payload: [String: Any] = [:]) async throws -> Favorite {
        try await request("favorites", method: "POST", body: ["type": type, "title": title, "payload": payload])
    }
    func deleteFavorite(_ id: String) async throws { let _: Ack = try await request("favorites/\(id)", method: "DELETE") }

    // MARK: uploads (multipart)
    func upload(images: [Data]) async throws -> UploadResponse {
        let boundary = "velo-\(UUID().uuidString)"
        var body = Data()
        for (i, img) in images.prefix(3).enumerated() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo\(i).jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(img)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: baseURL.appendingPathComponent("uploads"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "content-type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "authorization") }
        req.httpBody = body
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw APIError(status: 0, message: "upload failed")
        }
        return try decoder.decode(UploadResponse.self, from: data)
    }
}

// Simple bounding box (avoids importing MapKit types here).
struct MKBox {
    let minLon, minLat, maxLon, maxLat: Double
}
