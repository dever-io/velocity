import SwiftUI
import HealthKit

struct RideItem: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let meters: Double
    let duration: TimeInterval
    let avgHR: Double?
    var km: Double { meters / 1000 }
    var minutes: Int { Int(duration / 60) }
    var avgSpeed: Double { duration > 0 ? (meters / duration) * 3.6 : 0 }
}

@MainActor
@Observable
final class HealthManager {
    enum State { case idle, unavailable, needsPermission, authorized }
    private let store = HKHealthStore()
    var state: State = .idle
    var rides: [RideItem] = []

    func begin() {
        state = HKHealthStore.isHealthDataAvailable() ? .needsPermission : .unavailable
    }

    func requestAndLoad() async {
        guard HKHealthStore.isHealthDataAvailable() else { state = .unavailable; return }
        let read: Set<HKObjectType> = [.workoutType(), HKQuantityType(.heartRate), HKQuantityType(.distanceCycling)]
        try? await store.requestAuthorization(toShare: [], read: read)
        await load()
        state = .authorized
    }

    func load() async {
        let pred = HKQuery.predicateForWorkouts(with: .cycling)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let result: [HKWorkout] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: pred, limit: 20, sortDescriptors: [sort]) { _, samples, _ in
                cont.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(q)
        }
        rides = result.map { w in
            let meters = w.statistics(for: HKQuantityType(.distanceCycling))?.sumQuantity()?.doubleValue(for: .meter())
                ?? w.totalDistance?.doubleValue(for: .meter()) ?? 0
            return RideItem(title: "Заезд", date: w.endDate, meters: meters, duration: w.duration, avgHR: nil)
        }
    }
}

struct RidesView: View {
    @Environment(AppState.self) private var app
    @State private var hm = HealthManager()

    var body: some View {
        let loc = app.loc
        ScrollView {
            VStack(spacing: 16) {
                switch hm.state {
                case .idle, .needsPermission: permissionCard
                case .unavailable: unavailableCard
                case .authorized: grantedContent
                }
            }
            .padding(16)
        }
        .background(ScreenBackground())
        .navigationTitle(loc.s("ridesTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if hm.state == .idle { hm.begin() } }
    }

    private var permissionCard: some View {
        let loc = app.loc
        return VStack(spacing: 16) {
            Image(systemName: "heart.fill").font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                .frame(width: 66, height: 66).background(Theme.red, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.top, 20)
            Text(loc.s("healthTitle")).font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.tx)
            Text(loc.s("healthWhy")).font(.system(size: 14)).foregroundStyle(Theme.tx2).multilineTextAlignment(.center)
            PillTag(loc.s("healthPriv"), fg: Theme.green, bg: Theme.green.opacity(0.15), icon: "lock.fill")
            PrimaryButton(title: loc.s("healthConnect"), color: Theme.red, icon: "heart.fill") {
                Task { await hm.requestAndLoad() }
            }
            .padding(.top, 6)
        }
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))
        .vShadowS()
    }

    private var unavailableCard: some View {
        let loc = app.loc
        return VStack(spacing: 12) {
            Image(systemName: "heart.slash").font(.system(size: 40)).foregroundStyle(Theme.tx3).padding(.top, 40)
            Text(loc.s("healthUnavailable")).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.tx2)
                .multilineTextAlignment(.center)
        }
    }

    private var grantedContent: some View {
        let loc = app.loc
        return VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill").foregroundStyle(Theme.green)
                Text(loc.s("localOnly")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.green)
                Spacer()
            }
            .padding(12).background(Theme.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            if hm.rides.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bicycle").font(.system(size: 36)).foregroundStyle(Theme.tx3).padding(.top, 30)
                    Text(loc.s("ridesEmpty")).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.tx)
                    Text(loc.s("ridesEmptyHint")).font(.system(size: 13)).foregroundStyle(Theme.tx2).multilineTextAlignment(.center)
                }
            } else {
                ForEach(hm.rides) { ride in RideCard(ride: ride, loc: loc) }
            }
        }
    }
}

struct RideCard: View {
    let ride: RideItem
    let loc: Loc
    var body: some View {
        VCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(ride.title).font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.tx)
                    Spacer()
                    Text(ride.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12)).foregroundStyle(Theme.tx2)
                }
                MiniTrack().frame(height: 44)
                HStack(spacing: 0) {
                    stat(String(format: "%.1f", ride.km), "км")
                    stat("\(ride.minutes)", loc.s("durationL"))
                    stat(String(format: "%.0f", ride.avgSpeed), loc.s("avgSpeed"))
                    if let hr = ride.avgHR { stat("\(Int(hr))", loc.s("heartL")) }
                }
            }
        }
    }
    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 17, weight: .heavy)).foregroundStyle(Theme.tint)
            Text(l).font(.system(size: 11)).foregroundStyle(Theme.tx2)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MiniTrack: View {
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            let w = size.width, h = size.height
            p.move(to: CGPoint(x: 0, y: h * 0.7))
            p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.4),
                       control1: CGPoint(x: w * 0.2, y: h * 0.1), control2: CGPoint(x: w * 0.3, y: h * 0.8))
            p.addCurve(to: CGPoint(x: w, y: h * 0.3),
                       control1: CGPoint(x: w * 0.7, y: h * 0.1), control2: CGPoint(x: w * 0.85, y: h * 0.6))
            ctx.stroke(p, with: .color(Theme.tint), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }
}
