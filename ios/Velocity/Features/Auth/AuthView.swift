import SwiftUI

struct AuthView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let loc = app.loc
        ZStack {
            ScreenBackground()
            VStack {
                Spacer()
                VStack(spacing: 0) {
                    AppIconMark(size: 92)
                        .bob()
                    Text("Velocity")
                        .font(.system(size: 30, weight: .heavy)).tracking(-0.6)
                        .foregroundStyle(Theme.tx)
                        .padding(.top, 20)
                    Text(loc.s("signSub"))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.tx2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 260)
                        .padding(.top, 7)
                }
                Spacer()
                VStack(spacing: 11) {
                    Button { signIn() } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "apple.logo").font(.system(size: 18, weight: .medium))
                            Text(loc.s("signApple")).font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(Theme.appleFg)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Theme.appleBg, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                    }
                    .buttonStyle(PressStyle())

                    Button { signIn() } label: {
                        HStack(spacing: 9) {
                            Text("G").font(.system(size: 18, weight: .heavy)).foregroundStyle(Color(hex: 0x4285F4))
                            Text(loc.s("signGoogle")).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.tx)
                        }
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.button).stroke(Theme.sep, lineWidth: 1))
                    }
                    .buttonStyle(PressStyle())

                    Text(loc.s("signNote"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.tx3)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.top, 2)

                    Button { signIn() } label: {
                        Text(loc.s("guestEnter"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.tint)
                            .frame(maxWidth: .infinity).frame(height: 44)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
            if app.isSigningIn {
                Color.black.opacity(0.05).ignoresSafeArea()
                ProgressView().controlSize(.large)
            }
        }
    }

    private func signIn() { Task { await app.signInDev() } }
}

// App icon mark: gradient rounded square + white bike glyph (matches design).
struct AppIconMark: View {
    var size: CGFloat = 92
    var body: some View {
        Image(systemName: "bicycle")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.appIcon, in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            .shadow(color: Color(hex: 0x005ADC).opacity(0.4), radius: 18, x: 0, y: 16)
    }
}
