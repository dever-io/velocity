import Foundation
import CoreLocation

// Bilingual string from the backend.
struct Localized: Codable, Hashable {
    let ru: String
    let en: String
    func callAsFunction(_ lang: Lang) -> String { lang == .ru ? ru : en }
}

// ── Account / gamification ────────────────────────────────────────────────────
struct LevelInfo: Codable, Hashable {
    let level: Int
    let xp: Int
    let into: Int
    let need: Int
    let toNext: Int
    let progress: Double
}

struct Streak: Codable, Hashable { let count: Int; let best: Int }
struct Stats: Codable, Hashable { let edits: Int; let reports: Int; let confirms: Int }

struct Me: Codable, Hashable, Identifiable {
    let id: String
    let nickname: String
    let avatarLetter: String
    let locale: String
    let role: String
    let district: String
    let districtName: Localized
    let title: Localized
    let points: Int
    let level: LevelInfo
    let streak: Streak
    let kmTotal: Double
    let stats: Stats
}

struct AuthResponse: Codable { let token: String; let user: Me }

struct Quest: Codable, Identifiable, Hashable {
    let id: String
    let title: Localized
    let target: Int
    let rewardXp: Int
    let icon: String
    let color: String
    let progress: Int
    let claimed: Bool
    let completed: Bool
}

struct Badge: Codable, Identifiable, Hashable {
    let id: String
    let title: Localized
    let desc: Localized
    let icon: String
    let color: String
    let target: Int
    let progress: Int
    let earned: Bool
}
struct BadgesResponse: Codable { let earned: Int; let total: Int; let badges: [Badge] }

struct LeaderEntry: Codable, Identifiable, Hashable {
    var id: Int { rank ?? name.hashValue }
    let name: String
    let avatarLetter: String
    let avatarColor: String
    let xp: Int
    let isMe: Bool
    let rank: Int?
}
struct LeaderboardResponse: Codable { let board: String; let entries: [LeaderEntry] }

struct LeagueTier: Codable, Identifiable, Hashable {
    let id: String
    let title: Localized
    let color: String
    let current: Bool
}
struct LeagueResponse: Codable {
    let currentLeagueId: String
    let ladder: [LeagueTier]
    let entries: [LeaderEntry]
    let promotion: Int
    let demotion: Int
    let daysLeft: Int
}

struct SeasonReward: Codable, Identifiable, Hashable {
    var id: Int { tier }
    let tier: Int
    let icon: String
    let reward: Localized
    let state: String   // done | current | locked
}
struct SeasonResponse: Codable {
    let id: String
    let title: Localized
    let tiers: Int
    let currentTier: Int
    let daysLeft: Int
    let rewards: [SeasonReward]
}

// ── Rewards ───────────────────────────────────────────────────────────────────
struct Reward: Codable, Hashable {
    let points: Int
    let prevLevel: Int
    let level: Int
    let leveledUp: Bool
    let delta: Int
}

// ── Map GeoJSON ───────────────────────────────────────────────────────────────
struct FC<F: Codable>: Codable { let features: [F] }
struct LineGeometry: Codable { let coordinates: [[Double]] }
struct PointGeometry: Codable { let coordinates: [Double] }

struct SegmentProps: Codable {
    let kind: String
    let surface: String
    let smoothness: String?
    let mtbScale: String?
    let name: String?
    let source: String
    let updatedAt: String?
}
struct SegmentFeature: Codable, Identifiable {
    let id: String?
    let geometry: LineGeometry
    let properties: SegmentProps
    var coords: [CLLocationCoordinate2D] {
        geometry.coordinates.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
    }
}

struct POIProps: Codable {
    let kind: String
    let name: String
    let details: POIDetails?
    let source: String
}
struct POIDetails: Codable { let address: String?; let hours: String? }
struct POIFeature: Codable, Identifiable {
    let id: String?
    let geometry: PointGeometry
    let properties: POIProps
    var coord: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: geometry.coordinates[1], longitude: geometry.coordinates[0]) }
}

struct ReportProps: Codable {
    let category: String
    let comment: String?
    let confirmations: Int
    let status: String
    let photoKeys: [String]?
    let createdAt: String?
    let expiresAt: String?
    let reporter: String?
}
struct ReportFeature: Codable, Identifiable {
    let id: String?
    let geometry: PointGeometry
    let properties: ReportProps
    var coord: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: geometry.coordinates[1], longitude: geometry.coordinates[0]) }
}

// ── Routing / geocode ─────────────────────────────────────────────────────────
struct ElevationPoint: Codable, Hashable { let d: Int; let ele: Int }
struct RouteResult: Codable {
    let profile: String
    let geometry: LineGeometry
    let distance: Int
    let duration: Int
    let ascent: Int
    let infraPct: Int
    let elevation: [ElevationPoint]
    let source: String
    var coords: [CLLocationCoordinate2D] {
        geometry.coordinates.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
    }
}

struct GeocodeResult: Codable, Identifiable, Hashable {
    var id: String { "\(name)\(lng)\(lat)" }
    let name: String
    let subtitle: String?
    let lng: Double
    let lat: Double
    var coord: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
}
struct GeocodeResponse: Codable { let results: [GeocodeResult] }

// ── Community write responses ─────────────────────────────────────────────────
struct CreateReportResponse: Codable { let id: String; let status: String; let reward: Reward? }
struct VoteResponse: Codable { let ok: Bool; let confirmations: Int; let reward: Reward? }
struct EditResponse: Codable { let id: String; let status: String; let reward: Reward? }
struct QuestClaimResponse: Codable { let ok: Bool; let reward: Reward? }

// ── Favorites & contributions ─────────────────────────────────────────────────
struct Favorite: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let title: String
    let createdAt: String?
}

struct LedgerRow: Codable, Identifiable, Hashable {
    var id: String { "\(reason)\(createdAt ?? "")\(delta)" }
    let delta: Int
    let reason: String
    let refType: String?
    let createdAt: String?
}
struct EditRow: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let status: String
    let awarded: Int
    let createdAt: String?
}
struct ReportRow: Codable, Identifiable, Hashable {
    let id: String
    let category: String
    let comment: String?
    let status: String
    let confirmations: Int
    let createdAt: String?
}
struct Contributions: Codable {
    let points: Int
    let level: LevelInfo?
    let stats: Stats?
    let history: [LedgerRow]
    let edits: [EditRow]
    let reports: [ReportRow]
}

struct UploadItem: Codable { let key: String; let url: String }
struct UploadResponse: Codable { let uploads: [UploadItem] }
