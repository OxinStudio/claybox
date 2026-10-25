import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            switch model.screen {
            case .welcome: WelcomeView()
            case .enhancing: EnhanceView()
            case .ready: ReadyView()
            }
        }
        .overlay(alignment: .topTrailing) {
            HelpButton().padding(.top, 18).padding(.trailing, 20)
        }
        .frame(width: 1100, height: 720)
        .foregroundStyle(Theme.text)
        .animation(.easeInOut(duration: 0.25), value: model.screen)
        .sheet(isPresented: $model.showOnboarding) {
            OnboardingView()
                .environmentObject(model)
                .interactiveDismissDisabled()
        }
    }
}

// MARK: - 1. Welcome

struct WelcomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var dropTargeted = false

    var body: some View {
        ZStack {
            ClayBlob(color: Theme.clay, width: 380, height: 300, rotation: -12)
                .opacity(0.9)
                .position(x: 70, y: 720 - 40)
            ClayBlob(color: Theme.olive, width: 220, height: 190, rotation: 18)
                .position(x: 1100 + 50, y: 165)
            ClayBlob(color: Theme.mustard, width: 90, height: 80, rotation: -8)
                .position(x: 1100 - 195, y: 720 - 110)

            VStack(spacing: 0) {
                Spacer(minLength: 40)
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Text("1996 — 2026 · THIRTY YEARS IN CLAY")
                            .font(Theme.body(13, .semibold))
                            .tracking(2.8)
                            .foregroundStyle(Theme.accentText)
                        Text("Claybox")
                            .font(Theme.display(104))
                            .foregroundStyle(Theme.title)
                        Text("Play The Neverhood on your Mac — from your own disc, with backgrounds re-sculpted in HD.")
                            .font(Theme.body(19))
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 520)
                    }

                    dropZone

                    if let error = model.errorMessage {
                        Text(error)
                            .font(Theme.body(14, .semibold))
                            .foregroundStyle(Color(hex: 0xF0A08A))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 560)
                    } else {
                        Text("Claybox includes nothing from the game. You need your own original copy of The Neverhood.")
                            .font(Theme.body(13))
                            .foregroundStyle(Theme.faint)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 560)
                    }
                }
                Spacer(minLength: 40)
                Footer()
            }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 14) {
            Image(systemName: "opticaldisc")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.accentText)
            Text(model.busy ? "Copying the game from your disc…" : "Drop your disc or ISO here")
                .font(Theme.display(26, .semibold))
                .foregroundStyle(Theme.title)
            Text("Insert the original CD, or drag in an .iso made from it")
                .font(Theme.body(15))
                .foregroundStyle(Color(hex: 0xBCA592))
            Button("Choose file…") { model.chooseDisc() }
                .buttonStyle(ClayButtonStyle())
                .padding(.top, 6)
                .disabled(model.busy)
        }
        .padding(.vertical, 34)
        .frame(width: 560)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(dropTargeted ? Color(hex: 0x3D2A20) : Theme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(dropTargeted ? Theme.clay : Theme.dashed,
                                      style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                )
                .shadow(color: .black.opacity(0.35), radius: 20, y: 18)
        )
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { Task { await model.open(url) } }
            }
            return true
        }
    }
}

// MARK: - 2. Enhance

struct EnhanceView: View {
    @EnvironmentObject var model: AppModel
    private var fraction: Double { model.total > 0 ? Double(model.done) / Double(model.total) : 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 56) {
                VStack(alignment: .leading, spacing: 22) {
                    Label("Your disc was recognized — The Neverhood", systemImage: "checkmark")
                        .font(Theme.body(14, .semibold))
                        .foregroundStyle(Theme.ok)
                    Text("Re-sculpting the world in HD")
                        .font(Theme.display(56, .bold))
                        .foregroundStyle(Theme.title)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Claybox is upscaling every background from your disc, right here on your Mac. It only happens once — and you can start playing now: each scene turns HD as soon as it’s ready.")
                        .font(Theme.body(18))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: 440, alignment: .leading)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(model.total > 0 && model.done > 0 ? "\(model.done) of \(model.total) backgrounds" : model.stage)
                                .font(Theme.body(15, .semibold))
                                .foregroundStyle(Theme.soft)
                            Spacer()
                            Text(timeLeft)
                                .font(Theme.body(15))
                                .foregroundStyle(Theme.faint)
                        }
                        ClayProgressBar(fraction: fraction)
                    }
                    .padding(.top, 6)

                    HStack(spacing: 12) {
                        Button("Play now") { model.playNow() }
                            .buttonStyle(OutlineButtonStyle())
                            .help("Scenes switch to HD as soon as they’re ready")
                        Button("Skip HD for now") { model.skipEnhance() }
                            .buttonStyle(PlainTextButtonStyle())
                    }
                    .padding(.top, 10)

                    Label("Everything stays on this Mac. Nothing is uploaded.", systemImage: "lock")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.faint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                BirthdayScene()
                    .frame(width: 420, height: 340)
            }
            .padding(.horizontal, 64)
            .padding(.top, 36)
            .frame(maxHeight: .infinity)
            Footer()
        }
    }

    private var timeLeft: String {
        guard let s = model.secondsLeft else { return "" }
        if s < 60 { return "less than a minute left" }
        let m = Int((Double(s) / 60).rounded())
        return m == 1 ? "about 1 minute left" : "about \(m) minutes left"
    }
}

struct ClayProgressBar: View {
    var fraction: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                    .overlay(Capsule().stroke(Color.black.opacity(0.35), lineWidth: 2).blur(radius: 2).offset(y: 1).mask(Capsule()))
                Capsule().fill(Theme.clay)
                    .overlay(alignment: .top) { Capsule().fill(Color.white.opacity(0.22)).frame(height: 4).padding(.horizontal, 6).padding(.top, 2) }
                    .overlay(alignment: .bottom) { Capsule().fill(Color.black.opacity(0.2)).frame(height: 3).padding(.horizontal, 6) }
                    .frame(width: max(18, geo.size.width * fraction))
                    .animation(.easeOut(duration: 0.5), value: fraction)
            }
        }
        .frame(height: 18)
        .accessibilityElement()
        .accessibilityLabel("Backgrounds upscaled")
        .accessibilityValue("\(Int(fraction * 100)) percent")
    }
}

// MARK: - 3. Ready

struct ReadyView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    VStack(alignment: .leading, spacing: 10) {
                        Text("More")
                            .font(Theme.body(15, .semibold))
                            .foregroundStyle(Theme.muted)
                        HStack(spacing: 12) {
                            card(title: model.isEnhancing ? "Sculpting in HD…" : (model.hdImageCount > 0 ? "Re-sculpt HD" : "Make HD backgrounds"),
                                 subtitle: model.isEnhancing ? "\(model.done) of \(model.total) scenes" : (model.hdImageCount > 0 ? "\(model.hdImageCount) scenes ready" : "Runs on this Mac")) {
                                if model.isEnhancing { model.screen = .enhancing } else { model.startEnhance(redo: model.hdImageCount > 0) }
                            }
                            card(title: "Saved games", subtitle: "Load from the game's menu") {
                                NSWorkspace.shared.open(model.savesDir)
                            }
                            card(title: "About Claybox", subtitle: "By Oxin Studio · free & open source") {
                                NSWorkspace.shared.open(URL(string: "https://oxinstudio.com/apps/claybox/")!)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                settings
                    .frame(width: 300)
            }
            .padding(.horizontal, 56)
            .padding(.top, 24)
            .padding(.bottom, 36)
            .frame(maxHeight: .infinity)
            Footer()
        }
    }

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.line)
            ClayBlob(color: Theme.olive, width: 380, height: 240)
                .position(x: 150, y: 360 + 20)
            ClayBlob(color: Theme.earth, width: 440, height: 260)
                .position(x: 520, y: 360 + 40)
            ClayBlob(color: Theme.mustard, width: 110, height: 100)
                .position(x: 330, y: 250)

            VStack(alignment: .leading, spacing: 6) {
                Text(model.hdEnabled && model.hdImageCount > 0 ? "HD BACKGROUNDS READY" : "ORIGINAL GRAPHICS")
                    .font(Theme.body(13, .semibold))
                    .tracking(2.6)
                    .foregroundStyle(Color(hex: 0xF0C7A8))
                Text("The Neverhood")
                    .font(Theme.display(54))
                    .foregroundStyle(Color(hex: 0xFBEFE2))
            }
            .padding(.leading, 36)
            .padding(.top, 32)

            HStack {
                Spacer()
                Button {
                    model.play()
                } label: {
                    Label(model.isPlaying ? "Playing…" : "Play", systemImage: "play.fill")
                }
                .buttonStyle(ClayButtonStyle(large: true))
                .keyboardShortcut(.defaultAction)
                .disabled(model.isPlaying)
            }
            .padding(.top, 32)
            .padding(.trailing, 32)
        }
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 20, y: 18)
    }

    private func card(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Theme.body(15, .semibold)).foregroundStyle(Theme.text)
                Text(subtitle).font(Theme.body(13)).foregroundStyle(Theme.faint)
                    .lineLimit(1).minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.panel))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Picture")
                .font(Theme.body(15, .semibold))
                .foregroundStyle(Theme.muted)
            VStack(spacing: 0) {
                settingRow(title: "HD backgrounds",
                           subtitle: model.hdImageCount > 0 ? "\(model.hdImageCount) re-sculpted scenes" : "Not made yet",
                           isOn: $model.hdEnabled)
                Divider().overlay(Theme.ground)
                settingRow(title: "Smooth picture", subtitle: nil, isOn: $model.smoothPicture)
                Divider().overlay(Theme.ground)
                settingRow(title: "HD videos", subtitle: videoSubtitle, isOn: $model.hdVideos)
                Divider().overlay(Theme.ground)
                settingRow(title: "HD characters", subtitle: spriteSubtitle, isOn: $model.hdSprites)
                Divider().overlay(Theme.ground)
                settingRow(title: "Full screen", subtitle: nil, isOn: $model.fullScreen)
            }
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.panel))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("Disc")
                .font(Theme.body(15, .semibold))
                .foregroundStyle(Theme.muted)
                .padding(.top, 8)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.disc?.displayName ?? "No disc")
                        .font(Theme.body(15, .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("The Neverhood · Windows")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.faint)
                }
                Spacer()
                Button("Change") { model.forgetDisc() }
                    .buttonStyle(PlainTextButtonStyle(color: Theme.accentText))
            }
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.panel))

            if let error = model.errorMessage {
                Text(error)
                    .font(Theme.body(12, .semibold))
                    .foregroundStyle(Color(hex: 0xF0A08A))
            }

            Spacer()
            Text("Claybox is a free tribute for the game’s 30th anniversary. Not affiliated with the game’s creators or rights holders.")
                .font(Theme.body(12))
                .foregroundStyle(Color(hex: 0x8F7A69))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var spriteSubtitle: String {
        if model.isEnhancingSprites {
            if model.spriteTotal > 0 { return "\(model.spriteStage) \(model.spriteDone) of \(model.spriteTotal)" }
            return model.spriteDone > 0 ? "\(model.spriteStage) \(model.spriteDone) frames" : model.spriteStage
        }
        if model.hdSprites && !model.spritesComplete {
            return model.spriteStage.isEmpty ? "Paused — switch off and on to start" : model.spriteStage
        }
        if model.hdSprites && model.spritesComplete { return "Characters & objects re-sculpted" }
        return "Optional · about 20 minutes"
    }

    private var videoSubtitle: String {
        if model.isEnhancingVideos {
            let total = model.videoTotal > 0 ? "\(model.videoTotal)" : "…"
            var text = "Sculpting \(model.videoDone) of \(total)"
            if let s = model.videoSecondsLeft, s >= 60 {
                let h = s / 3600, m = (s % 3600) / 60
                text += h > 0 ? " · about \(h)h \(m)m left" : " · about \(m) min left"
            }
            return text
        }
        if model.hdVideos && !model.videoComplete {
            return model.hdVideoCount > 0 ? "\(model.hdVideoCount) done · paused — switch off and on to continue"
                                          : "Paused — switch off and on to start"
        }
        if model.hdVideos && model.hdVideoCount > 0 { return "\(model.hdVideoCount) videos re-sculpted" }
        return "Optional · takes a while, about 3 GB"
    }

    private func settingRow(title: String, subtitle: String?, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.body(15, .semibold))
                if let subtitle {
                    Text(subtitle).font(Theme.body(12)).foregroundStyle(Theme.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Theme.clay)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
    }
}
