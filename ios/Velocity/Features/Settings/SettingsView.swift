import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @State private var confirmDelete = false

    var body: some View {
        @Bindable var app = app
        let loc = app.loc
        Form {
            Section {
                Picker(loc.s("language"), selection: $app.lang) {
                    Text("Русский").tag(Lang.ru)
                    Text("English").tag(Lang.en)
                }.pickerStyle(.segmented)
                Picker(loc.s("theme"), selection: $app.themeMode) {
                    Text(loc.s("themeSystem")).tag(ThemeMode.system)
                    Text(loc.s("themeLight")).tag(ThemeMode.light)
                    Text(loc.s("themeDark")).tag(ThemeMode.dark)
                }.pickerStyle(.segmented)
            }

            Section {
                NavigationLink { AboutView() } label: { Label(loc.s("about"), systemImage: "info.circle") }
                NavigationLink { PrivacyView() } label: { Label(loc.s("privacyItem"), systemImage: "hand.raised") }
                NavigationLink { RulesView() } label: { Label(loc.s("rulesItem"), systemImage: "checklist") }
            }

            Section {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label(loc.s("deleteAcc"), systemImage: "trash")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(loc.s("versionL")) \(appVersion)").font(.system(size: 13)).foregroundStyle(Theme.tx2)
                    Text(loc.s("odblNote")).font(.system(size: 12)).foregroundStyle(Theme.tx3)
                }
            }
        }
        .navigationTitle(loc.s("settingsTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(loc.s("deleteConfirm"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(loc.s("deleteAcc"), role: .destructive) { Task { await app.deleteAccount() } }
            Button(loc.s("cancel"), role: .cancel) {}
        } message: {
            Text(loc.s("deleteWarn"))
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}

struct AboutView: View {
    @Environment(AppState.self) private var app
    var body: some View {
        let loc = app.loc
        ScrollView {
            VStack(spacing: 16) {
                AppIconMark(size: 84).padding(.top, 20)
                Text("Velocity").font(.system(size: 26, weight: .heavy)).foregroundStyle(Theme.tx)
                Text(loc.s("aboutTagline")).font(.system(size: 15)).foregroundStyle(Theme.tx2).multilineTextAlignment(.center)

                VCard {
                    HStack(spacing: 12) {
                        Image(systemName: "map.fill").foregroundStyle(Theme.cProt)
                        Text(loc.s("osmAttribution")).font(.system(size: 14)).foregroundStyle(Theme.tx)
                        Spacer()
                    }
                }
                VCard {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.orange)
                        Text(loc.s("routesAdvisory")).font(.system(size: 13)).foregroundStyle(Theme.tx2)
                    }
                }
            }
            .padding(16)
        }
        .background(ScreenBackground())
        .navigationTitle(loc.s("about"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyView: View {
    @Environment(AppState.self) private var app
    var body: some View {
        let loc = app.loc
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(loc.s("signNote")).font(.system(size: 15)).foregroundStyle(Theme.tx)
                Text(loc.s("healthWhy")).font(.system(size: 14)).foregroundStyle(Theme.tx2)
                Text(loc.s("odblNote")).font(.system(size: 13)).foregroundStyle(Theme.tx3)
            }
            .padding(16)
        }
        .background(ScreenBackground())
        .navigationTitle(loc.s("privacyItem"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RulesView: View {
    @Environment(AppState.self) private var app
    var body: some View {
        let loc = app.loc
        let rules = [("rule1t", "rule1d"), ("rule2t", "rule2d"), ("rule3t", "rule3d"), ("rule4t", "rule4d")]
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(rules.enumerated()), id: \.offset) { i, r in
                    VCard {
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(i + 1)").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                                .frame(width: 28, height: 28).background(Theme.tint, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loc.s(r.0)).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.tx)
                                Text(loc.s(r.1)).font(.system(size: 14)).foregroundStyle(Theme.tx2)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(ScreenBackground())
        .navigationTitle(loc.s("rulesTitle"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
