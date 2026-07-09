import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var app
    @State private var page = 0

    private var slides: [(String, String)] {
        let l = app.loc
        return [(l.s("ob1t"), l.s("ob1d")), (l.s("ob2t"), l.s("ob2d")), (l.s("ob3t"), l.s("ob3d"))]
    }

    var body: some View {
        let loc = app.loc
        ZStack {
            ScreenBackground()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(loc.s("skip")) { app.completeOnboarding() }
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.tx2)
                        .padding(8)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)

                TabView(selection: $page) {
                    ForEach(0..<slides.count, id: \.self) { i in
                        VStack(spacing: 0) {
                            RouteArt(variant: i)
                                .frame(width: 230, height: 200)
                            Text(slides[i].0)
                                .font(.system(size: 27, weight: .heavy)).tracking(-0.6)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Theme.tx)
                                .padding(.top, 30)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(slides[i].1)
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.tx2)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.top, 13)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 34)
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: page)

                HStack(spacing: 7) {
                    ForEach(0..<slides.count, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Theme.tint : Theme.tx3)
                            .frame(width: i == page ? 18 : 7, height: 7)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }
                .padding(.bottom, 26)

                PrimaryButton(title: page == slides.count - 1 ? loc.s("start") : loc.s("next")) {
                    if page < slides.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        app.completeOnboarding()
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 46)
            }
        }
    }
}

// Stylized route illustration for onboarding slides.
struct RouteArt: View {
    var variant: Int
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.card2)
                .frame(width: 230, height: 150)
                .vShadowS()
            Canvas { ctx, size in
                let w = size.width, h = size.height
                func line(_ pts: [CGPoint], _ color: Color, _ width: CGFloat, dash: [CGFloat] = []) {
                    var p = Path()
                    p.move(to: pts[0]); pts.dropFirst().forEach { p.addLine(to: $0) }
                    ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash))
                }
                line([CGPoint(x: w*0.12, y: h*0.8), CGPoint(x: w*0.4, y: h*0.5), CGPoint(x: w*0.6, y: h*0.55), CGPoint(x: w*0.88, y: h*0.25)], Theme.cProt, 6)
                line([CGPoint(x: w*0.1, y: h*0.35), CGPoint(x: w*0.45, y: h*0.3), CGPoint(x: w*0.7, y: h*0.7)], Theme.cLane, 5)
                line([CGPoint(x: w*0.2, y: h*0.15), CGPoint(x: w*0.55, y: h*0.85)], Theme.cMtb, 4, dash: [3, 8])
                let dot = CGRect(x: w*0.6 - 6, y: h*0.55 - 6, width: 12, height: 12)
                ctx.fill(Circle().path(in: dot), with: .color(Theme.tint))
                ctx.stroke(Circle().path(in: dot), with: .color(.white), lineWidth: 2.5)
            }
            .frame(width: 230, height: 150)
            Image(systemName: variant == 0 ? "map.fill" : variant == 1 ? "point.topleft.down.to.point.bottomright.curvepath.fill" : "person.2.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .padding(10)
                .background(Theme.tint, in: Circle())
                .offset(x: 78, y: 52)
        }
    }
}
