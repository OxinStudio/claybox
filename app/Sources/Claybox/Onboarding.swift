import SwiftUI

// First-launch tour: four short pages that explain what Claybox does and what the user should do.
// Shown once automatically; can be reopened from Help ▸ Welcome Tour.

struct OnboardingPage: Identifiable {
    let id: Int
    let symbol: String
    let blob: Color
    let eyebrow: String
    let title: String
    let body: String
    let points: [(String, String)]   // (SF Symbol, text)
}

enum OnboardingContent {
    static let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0, symbol: "sparkles", blob: Theme.clay,
            eyebrow: "WELCOME",
            title: "Welcome to Claybox",
            body: "Claybox plays The Neverhood on your Mac, from your own copy of the game, and can re-sculpt it in HD.",
            points: [
                ("opticaldisc", "You need your own original copy of the game (the Windows CD, or an ISO made from it)."),
                ("gift", "Claybox is free and includes nothing from the game itself."),
                ("lock", "Everything happens on this Mac. Nothing is uploaded."),
            ]),
        OnboardingPage(
            id: 1, symbol: "opticaldisc", blob: Theme.olive,
            eyebrow: "STEP 1",
            title: "Add your game",
            body: "Drop your disc or ISO onto the Claybox window, or click Choose file…",
            points: [
                ("square.and.arrow.down", "Claybox copies the game files to this Mac once. After that, you don’t need the disc."),
                ("externaldrive", "No CD drive? Make an ISO of the disc on any computer with a drive, then drop the .iso here."),
                ("checkmark.circle", "Claybox checks that it’s The Neverhood before going on."),
            ]),
        OnboardingPage(
            id: 2, symbol: "wand.and.stars", blob: Theme.mustard,
            eyebrow: "STEP 2",
            title: "Re-sculpt in HD",
            body: "Claybox uses AI on your Mac to redraw every background at twice the detail. This happens once.",
            points: [
                ("clock", "Takes about 40 minutes on a recent Mac. Keep the Mac plugged in."),
                ("play.circle", "You can play right away. Each scene turns HD as soon as it’s ready."),
                ("slider.horizontal.3", "Later you can add HD characters and HD videos. Both are optional switches."),
            ]),
        OnboardingPage(
            id: 3, symbol: "play.fill", blob: Theme.earth,
            eyebrow: "STEP 3",
            title: "Play",
            body: "Click Play. The game opens in its own window, and Claybox steps aside until you’re done.",
            points: [
                ("cursorarrow.click", "Click where you want to go or what you want to use. That’s the whole game."),
                ("escape", "Esc opens the game’s menu: save, load and quit."),
                ("questionmark.circle", "Stuck? Help ▸ Claybox Help (⌘?) has controls and fixes for common problems."),
            ]),
    ]
}

struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    @State private var index = 0
    private let pages = OnboardingContent.pages

    var body: some View {
        let page = pages[index]
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 40) {
                illustration(page)
                    .frame(width: 220, height: 260)

                VStack(alignment: .leading, spacing: 14) {
                    Text(page.eyebrow)
                        .font(Theme.body(12, .semibold))
                        .tracking(2.4)
                        .foregroundStyle(Theme.accentText)
                    Text(page.title)
                        .font(Theme.display(40, .bold))
                        .foregroundStyle(Theme.title)
                    Text(page.body)
                        .font(Theme.body(16))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(page.points.enumerated()), id: \.offset) { _, point in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: point.0)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.accentText)
                                    .frame(width: 22)
                                Text(point.1)
                                    .font(Theme.body(14))
                                    .foregroundStyle(Theme.soft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, 6)
                    if index == pages.count - 1 {
                        Text("Made with care by Oxin Studio, Calgary.")
                            .font(Theme.body(13, .semibold))
                            .foregroundStyle(Theme.faint)
                            .padding(.top, 10)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 44)
            .padding(.top, 44)
            .frame(maxHeight: .infinity, alignment: .top)
            .id(index)
            .transition(.opacity)

            HStack {
                pageDots
                Spacer()
                if index == 0 {
                    Button("Skip") { finish() }
                        .buttonStyle(PlainTextButtonStyle())
                } else {
                    Button("Back") { withAnimation { index -= 1 } }
                        .buttonStyle(PlainTextButtonStyle())
                }
                Button(index == pages.count - 1 ? "Get started" : "Next") {
                    if index == pages.count - 1 { finish() } else { withAnimation { index += 1 } }
                }
                .buttonStyle(ClayButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 18)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        }
        .frame(width: 760, height: 520)
        .background(Theme.ground)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
    }

    private func finish() {
        model.finishOnboarding()
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(pages) { p in
                Capsule()
                    .fill(p.id == index ? Theme.clay : Theme.line)
                    .frame(width: p.id == index ? 22 : 8, height: 8)
                    .animation(.easeOut(duration: 0.2), value: index)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Page \(index + 1) of \(pages.count)")
    }

    private func illustration(_ page: OnboardingPage) -> some View {
        ZStack {
            ClayBlob(color: page.blob, width: 200, height: 180, rotation: -10)
                .offset(x: -6, y: 10)
            ClayBlob(color: Theme.panel, width: 70, height: 60, rotation: 14)
                .offset(x: 78, y: -88)
            ClayBlob(color: Theme.clay.opacity(page.blob == Theme.clay ? 0 : 1), width: 46, height: 40, rotation: -20)
                .offset(x: -82, y: 96)
            Image(systemName: page.symbol)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(Theme.ground.opacity(0.85))
                .offset(x: -6, y: 10)
        }
        .accessibilityHidden(true)
    }
}
