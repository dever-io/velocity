import SwiftUI
import CoreLocation

struct AddPOIFlow: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let coordinate: CLLocationCoordinate2D

    @State private var name = ""
    @State private var kind = "workshop"
    @State private var busy = false

    private let kinds = ["workshop", "parking", "rental", "fountain"]
    private func icon(_ k: String) -> String {
        switch k {
        case "workshop": return "wrench.and.screwdriver.fill"
        case "parking": return "parkingsign"
        case "rental": return "bicycle"
        default: return "drop.fill"
        }
    }

    var body: some View {
        let loc = app.loc
        VStack(spacing: 0) {
            FlowNavBar(title: loc.s("poiAddTitle")) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(loc.s("poiNameL")).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.tx2)
                    TextField(loc.s("poiNamePh"), text: $name)
                        .font(.system(size: 16)).padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    Text(loc.s("poiTypeL")).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.tx2)
                    VStack(spacing: 8) {
                        ForEach(kinds, id: \.self) { k in
                            Button { kind = k } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: icon(k)).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                                        .frame(width: 38, height: 38)
                                        .background(Theme.poiColor(k), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                    Text(loc.poiKind(k)).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.tx)
                                    Spacer()
                                    if kind == k { Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.poiColor(k)) }
                                }
                                .padding(.horizontal, 12).frame(height: 58)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 13).stroke(kind == k ? Theme.poiColor(k) : Theme.sep, lineWidth: kind == k ? 2 : 1))
                            }
                            .buttonStyle(PressStyle())
                        }
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "location.fill").foregroundStyle(Theme.tint)
                        Text(loc.s("locationL")).font(.system(size: 14)).foregroundStyle(Theme.tx)
                        Spacer()
                    }
                    .padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle").foregroundStyle(Theme.tx3)
                        Text(loc.s("reviewNote")).font(.system(size: 13)).foregroundStyle(Theme.tx2)
                    }
                }
                .padding(16)
            }
            PrimaryButton(title: loc.s("drawSubmit"), color: Theme.tint, enabled: !name.isEmpty && !busy) { submit() }
                .padding(16)
        }
        .background(ScreenBackground())
    }

    private func submit() {
        busy = true
        let geometry: [String: Any] = ["type": "Point", "coordinates": [coordinate.longitude, coordinate.latitude]]
        let payload: [String: Any] = ["kind": kind, "name": name]
        Task {
            let resp = try? await APIClient.shared.createEdit(type: "new_poi", geometry: geometry, payload: payload, photoKeys: [])
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                app.handleReward(resp?.reward, toast: app.loc.s("poiSuccess"))
            }
        }
    }
}
