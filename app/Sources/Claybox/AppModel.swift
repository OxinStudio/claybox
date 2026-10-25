import SwiftUI
import AppKit

struct Disc: Equatable {
    let source: URL      // the .iso or the folder the user gave us
    let mountPoint: URL? // set when we mounted an ISO ourselves
    let dataFolder: URL  // the folder holding the game's .blb files
    let gameFolder: URL  // what we hand to the engine as the game path

    var displayName: String {
        UserDefaults.standard.string(forKey: "discName") ?? source.lastPathComponent
    }
}

@MainActor
final class AppModel: ObservableObject {
    enum Screen { case welcome, enhancing, ready }

    @Published var screen: Screen = .welcome
    @Published var disc: Disc?
    @Published var errorMessage: String?
    @Published var busy = false

    // Enhance progress
    @Published var stage = ""
    @Published var done = 0
    @Published var total = 0
    @Published var secondsLeft: Int?

    @Published var isPlaying = false
    /// First-launch tour (Help ▸ Welcome Tour shows it again)
    @Published var showOnboarding = false
    @Published var isEnhancing = false
    var hdComplete: Bool {
        get { defaults.bool(forKey: "hdComplete") }
        set { defaults.set(newValue, forKey: "hdComplete") }
    }

    // Settings (remembered)
    @Published var hdEnabled: Bool { didSet { defaults.set(hdEnabled, forKey: "hdEnabled") } }
    @Published var smoothPicture: Bool { didSet { defaults.set(smoothPicture, forKey: "smoothPicture") } }
    @Published var fullScreen: Bool { didSet { defaults.set(fullScreen, forKey: "fullScreen") } }
    /// Optional: HD videos (made on this Mac; takes a while and a few GB)
    @Published var hdVideos: Bool {
        didSet {
            defaults.set(hdVideos, forKey: "hdVideos")
            if hdVideos && !videoComplete && !isEnhancingVideos && !isEnhancing { startVideoEnhance() }
            if !hdVideos { videoTask?.cancel() }
        }
    }
    @Published var isEnhancingVideos = false
    @Published var videoDone = 0
    @Published var videoTotal = 0
    @Published var videoSecondsLeft: Int?
    var videoComplete: Bool {
        get { defaults.bool(forKey: "videoComplete") }
        set { defaults.set(newValue, forKey: "videoComplete") }
    }
    private var videoTask: Task<Void, Never>?

    /// Optional: HD characters & objects (animation frames)
    @Published var hdSprites: Bool {
        didSet {
            defaults.set(hdSprites, forKey: "hdSprites")
            if hdSprites && !spritesComplete { startSpriteEnhanceWhenFree() }
            if !hdSprites { spriteTask?.cancel() }
        }
    }
    @Published var isEnhancingSprites = false
    @Published var spriteStage = ""
    @Published var spriteDone = 0
    @Published var spriteTotal = 0
    /// Bump when the sprite pipeline changes, so existing users re-run it once.
    static let spritesVersion = 3
    var spritesComplete: Bool {
        get { defaults.bool(forKey: "spritesComplete") && defaults.integer(forKey: "spritesVersion") == Self.spritesVersion }
        set {
            defaults.set(newValue, forKey: "spritesComplete")
            defaults.set(newValue ? Self.spritesVersion : 0, forKey: "spritesVersion")
        }
    }
    private var spriteTask: Task<Void, Never>?
    private var spritesWaiting = false

    private let defaults = UserDefaults.standard
    private var enhanceTask: Task<Void, Never>?
    private var gameProcess: Process?

    let supportDir: URL
    var hdDir: URL { supportDir.appendingPathComponent("hd", isDirectory: true) }
    var savesDir: URL { supportDir.appendingPathComponent("saves", isDirectory: true) }
    var hdVideoDir: URL { supportDir.appendingPathComponent("hd-video", isDirectory: true) }
    var hdSpriteDir: URL { supportDir.appendingPathComponent("hd-sprites", isDirectory: true) }
    var hdVideoCount: Int {
        (try? FileManager.default.contentsOfDirectory(atPath: hdVideoDir.path)
            .filter { !$0.hasPrefix(".") && !$0.hasSuffix(".tmp") }.count) ?? 0
    }
    var workDir: URL { supportDir.appendingPathComponent("work", isDirectory: true) }
    /// The game files, copied once from the user's own disc, so the disc isn't needed again.
    var gameDir: URL { supportDir.appendingPathComponent("game", isDirectory: true) }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        supportDir = base.appendingPathComponent("Claybox", isDirectory: true)
        hdEnabled = defaults.object(forKey: "hdEnabled") as? Bool ?? true
        smoothPicture = defaults.object(forKey: "smoothPicture") as? Bool ?? true
        fullScreen = defaults.object(forKey: "fullScreen") as? Bool ?? false
        hdVideos = defaults.object(forKey: "hdVideos") as? Bool ?? false
        hdSprites = defaults.object(forKey: "hdSprites") as? Bool ?? false
        showOnboarding = !defaults.bool(forKey: "onboardingDone")
        for dir in [supportDir, hdDir, savesDir, workDir] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        if GameDisc.dataFolder(in: gameDir) != nil {
            let dir = gameDir
            Task { await open(dir, remembered: true) }
        }
    }

    var hdImageCount: Int {
        (try? FileManager.default.contentsOfDirectory(atPath: hdDir.path)
            .filter { $0.hasSuffix(".png") && !$0.hasSuffix(".tmp.png") }.count) ?? 0
    }

    // MARK: Disc

    func chooseDisc() {
        let panel = NSOpenPanel()
        panel.title = "Choose your disc or ISO"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.diskImage, .folder, .volume]
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url {
            Task { await open(url) }
        }
    }

    func open(_ url: URL, remembered: Bool = false) async {
        errorMessage = nil
        busy = true
        defer { busy = false }
        do {
            let source = try await Self.prepareDisc(url)
            let installed = try await Self.install(from: source, to: gameDir)
            if source.mountPoint != nil { Self.detach(source) }
            disc = installed
            if url.standardizedFileURL != gameDir.standardizedFileURL {
                defaults.set(url.lastPathComponent, forKey: "discName")
            }
            if !hdEnabled || hdComplete {
                screen = .ready
            } else if hdImageCount > 0 {
                // pick up where the last run stopped, quietly
                screen = .ready
                startEnhance(showScreen: false)
            } else {
                startEnhance()
            }
        } catch {
            if !remembered { errorMessage = error.localizedDescription }
        }
    }

    nonisolated static func prepareDisc(_ url: URL) async throws -> Disc {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        if isDir.boolValue {
            guard let data = GameDisc.dataFolder(in: url) else { throw ClayError.notTheGame }
            return Disc(source: url, mountPoint: nil, dataFolder: data, gameFolder: url)
        }
        let mount = try mountImage(url)
        guard let data = GameDisc.dataFolder(in: mount) else {
            detach(Disc(source: url, mountPoint: mount, dataFolder: mount, gameFolder: mount))
            throw ClayError.notTheGame
        }
        return Disc(source: url, mountPoint: mount, dataFolder: data, gameFolder: mount)
    }

    /// Copies the game's data files from the disc into Claybox's own folder (once).
    nonisolated static func install(from disc: Disc, to gameDir: URL) async throws -> Disc {
        let local = { (dir: URL) in Disc(source: dir, mountPoint: nil, dataFolder: dir.appendingPathComponent("DATA"), gameFolder: dir) }
        if disc.gameFolder.standardizedFileURL == gameDir.standardizedFileURL { return local(gameDir) }
        return try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let staging = gameDir.deletingLastPathComponent().appendingPathComponent("game-copying", isDirectory: true)
            try? fm.removeItem(at: staging)
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)
            try fm.copyItem(at: disc.dataFolder, to: staging.appendingPathComponent("DATA"))
            // make sure the copy is readable/writable by us (files on a CD are read-only)
            for sub in (try? fm.subpathsOfDirectory(atPath: staging.path)) ?? [] {
                try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: staging.appendingPathComponent(sub).path)
            }
            guard GameDisc.dataFolder(in: staging) != nil else { throw ClayError.notTheGame }
            try? fm.removeItem(at: gameDir)
            try fm.moveItem(at: staging, to: gameDir)
            return local(gameDir)
        }.value
    }

    /// Where Claybox mounts disc images: its own folder, not /Volumes, so the game engine
    /// (a helper process) can always reach the files and nothing appears on the desktop.
    nonisolated static var discMountPoint: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Claybox/disc", isDirectory: true)
    }

    nonisolated static func mountImage(_ url: URL) throws -> URL {
        let fm = FileManager.default
        let target = discMountPoint
        // Already mounted from an earlier run?
        if GameDisc.dataFolder(in: target) != nil { return target }
        // Something else (or a stale mount) is there: try to release it, then start clean.
        if let items = try? fm.contentsOfDirectory(atPath: target.path), !items.isEmpty {
            let d = Process()
            d.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            d.arguments = ["detach", "-force", "-quiet", target.path]
            try? d.run(); d.waitUntilExit()
        }
        try? fm.removeItem(at: target)
        try fm.createDirectory(at: target, withIntermediateDirectories: true)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        p.arguments = ["attach", "-readonly", "-nobrowse", "-noverify", "-noautoopen",
                       "-mountpoint", target.path, "-plist", url.path]
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        try p.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0,
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]],
              let mount = entities.compactMap({ $0["mount-point"] as? String }).first
        else {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw ClayError.mountFailed(msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        // If the image was already attached somewhere else (e.g. opened in Finder), hdiutil reuses that mount.
        return URL(fileURLWithPath: mount, isDirectory: true)
    }

    nonisolated static func detach(_ disc: Disc) {
        guard let mount = disc.mountPoint else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        p.arguments = ["detach", "-quiet", mount.path]
        try? p.run()
        p.waitUntilExit()
    }

    func forgetDisc() {
        if let d = disc { Self.detach(d) }
        disc = nil
        try? FileManager.default.removeItem(at: gameDir)
        defaults.removeObject(forKey: "discName")
        screen = .welcome
    }

    func shutdown() {
        enhanceTask?.cancel()
        videoTask?.cancel()
        spriteTask?.cancel()
        gameProcess?.terminate()
        if let d = disc { Self.detach(d) }
    }

    // MARK: Enhance

    func startEnhance(showScreen: Bool = true, redo: Bool = false) {
        guard let disc else { return }
        if showScreen { screen = .enhancing }
        enhanceTask?.cancel()
        if redo {
            try? FileManager.default.removeItem(at: hdDir)
            hdComplete = false
        }
        isEnhancing = true
        done = 0; total = 0; secondsLeft = nil
        stage = "Reading your disc…"
        let hd = hdDir, work = workDir
        enhanceTask = Task {
            do {
                try await Enhancer.run(dataFolder: disc.dataFolder, workDir: work, hdDir: hd) { update in
                    await MainActor.run {
                        self.stage = update.stage
                        self.done = update.done
                        self.total = update.total
                        self.secondsLeft = update.secondsLeft
                    }
                }
                if !Task.isCancelled {
                    hdComplete = true
                    if screen == .enhancing { screen = .ready }
                }
                isEnhancing = false
                if spritesWaiting { startSpriteEnhanceWhenFree() }
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
                if screen == .enhancing { screen = .ready }
            }
            isEnhancing = false
        }
    }

    func skipEnhance() {
        enhanceTask?.cancel()
        isEnhancing = false
        screen = .ready
    }

    /// Start playing while the HD backgrounds keep coming in.
    func playNow() {
        screen = .ready
        play()
    }

    // MARK: HD videos (optional)

    func startVideoEnhance() {
        guard let disc, !isEnhancingVideos else { return }
        guard let resources = Bundle.main.resourceURL else { return }
        let engine = Helpers.engine
        isEnhancingVideos = true
        let config = engineConfig(gameFolder: disc.gameFolder, useHD: false)
        let configURL = supportDir.appendingPathComponent("claybox-videos.ini")
        let logURL = supportDir.appendingPathComponent("videos.log")
        let work = workDir, out = hdVideoDir
        videoTask = Task {
            do {
                try await VideoEnhancer.run(engine: engine, configText: config, configURL: configURL, logURL: logURL,
                                            workDir: work, outDir: out) { update in
                    await MainActor.run {
                        self.videoDone = update.done
                        self.videoTotal = update.total
                        self.videoSecondsLeft = update.secondsLeft
                    }
                }
                if !Task.isCancelled { videoComplete = true }
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
            isEnhancingVideos = false
            if spritesWaiting { startSpriteEnhanceWhenFree() }
        }
    }

    // MARK: HD characters (optional)

    /// One GPU job at a time: wait for backgrounds/videos to finish first.
    func startSpriteEnhanceWhenFree() {
        guard hdSprites, !spritesComplete, !isEnhancingSprites else { return }
        if isEnhancing || isEnhancingVideos {
            spritesWaiting = true
            spriteStage = "Waiting for the other HD work to finish…"
            return
        }
        spritesWaiting = false
        startSpriteEnhance()
    }

    private func startSpriteEnhance() {
        guard let disc, let resources = Bundle.main.resourceURL else { return }
        let engine = Helpers.engine
        isEnhancingSprites = true
        spriteDone = 0; spriteTotal = 0
        let config = engineConfig(gameFolder: disc.gameFolder, useHD: false)
        let configURL = supportDir.appendingPathComponent("claybox-sprites.ini")
        let logURL = supportDir.appendingPathComponent("sprites.log")
        let work = workDir, out = hdSpriteDir
        spriteTask = Task {
            do {
                try await SpriteEnhancer.run(engine: engine, configText: config, configURL: configURL, logURL: logURL,
                                             workDir: work, outDir: out) { update in
                    await MainActor.run {
                        self.spriteStage = update.stage
                        self.spriteDone = update.done
                        self.spriteTotal = update.total
                    }
                }
                if !Task.isCancelled { spritesComplete = true }
            } catch is CancellationError {
            } catch {
                errorMessage = "HD characters: " + error.localizedDescription
            }
            isEnhancingSprites = false
        }
    }

    func engineConfig(gameFolder: URL, useHD: Bool) -> String {
        let resources = Bundle.main.resourceURL!
        let videos = hdVideos && hdVideoCount > 0
        let sprites = hdSprites && spritesComplete && FileManager.default.fileExists(atPath: hdSpriteDir.path)
        return """
        [scummvm]
        gfx_mode=opengl
        fullscreen=\(fullScreen)
        filtering=\(smoothPicture)
        aspect_ratio=true
        savepath=\(savesDir.path)
        confirm_exit=false
        gui_return_to_launcher_at_exit=false
        gui_theme=builtin

        [neverhood]
        gameid=neverhood
        engineid=neverhood
        description=The Neverhood
        path=\(gameFolder.path)
        extrapath=\(resources.appendingPathComponent("engine-data").path)
        claybox_hd=\(useHD || videos || sprites)
        claybox_hd_path=\(hdDir.path)
        claybox_smooth=\(smoothPicture)
        \(videos ? "claybox_video_path=\(hdVideoDir.path)" : "")
        \(sprites ? "claybox_sprite_path=\(hdSpriteDir.path)" : "")
        """
    }

    // MARK: Help

    func finishOnboarding() {
        defaults.set(true, forKey: "onboardingDone")
        showOnboarding = false
    }

    func revealSaves() {
        try? FileManager.default.createDirectory(at: savesDir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(savesDir)
    }

    func revealEngineLog() {
        if FileManager.default.fileExists(atPath: engineLog.path) {
            NSWorkspace.shared.activateFileViewerSelecting([engineLog])
        } else {
            NSWorkspace.shared.open(supportDir)
        }
    }

    func revealSupportFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([supportDir])
    }

    // MARK: Play

    func play() {
        guard disc != nil, !isPlaying else { return }
        Task { await playChecked() }
    }

    private var engineLog: URL { supportDir.appendingPathComponent("engine.log") }

    private func playChecked() async {
        guard var current = disc else { return }
        errorMessage = nil
        // The disc image may have been ejected meanwhile (Finder, sleep, another app): mount it again.
        if GameDisc.dataFolder(in: current.gameFolder) == nil {
            do {
                current = try await Self.prepareDisc(current.source)
                disc = current
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
        do {
            let resources = Bundle.main.resourceURL!
            let engine = Helpers.engine
            guard FileManager.default.isExecutableFile(atPath: engine.path) else { throw ClayError.toolMissing("game engine") }
            let config = supportDir.appendingPathComponent("claybox.ini")
            let useHD = hdEnabled && (hdImageCount > 0 || isEnhancing)
            let ini = engineConfig(gameFolder: current.gameFolder, useHD: useHD)
            try ini.write(to: config, atomically: true, encoding: .utf8)

            FileManager.default.createFile(atPath: engineLog.path, contents: nil)
            let log = try FileHandle(forWritingTo: engineLog)

            let p = Process()
            p.executableURL = engine
            p.arguments = ["--config=\(config.path)", "neverhood"]
            p.standardOutput = log
            p.standardError = log
            let started = Date()
            p.terminationHandler = { [weak self] proc in
                let status = proc.terminationStatus
                let quick = Date().timeIntervalSince(started) < 20
                try? log.close()
                Task { @MainActor in
                    guard let self else { return }
                    self.isPlaying = false
                    self.gameProcess = nil
                    if status != 0 || quick {
                        let lines = (try? String(contentsOf: self.engineLog, encoding: .utf8))?
                            .split(separator: "\n").map(String.init) ?? []
                        let reason = lines.last(where: { $0.contains("Error") || $0.contains("error") || $0.contains("not found") }) ?? lines.last ?? ""
                        if status != 0 || reason.lowercased().contains("error") || reason.contains("not found") {
                            self.errorMessage = "The game stopped unexpectedly. \(reason)"
                        }
                    }
                    NSApp.unhide(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            try p.run()
            gameProcess = p
            isPlaying = true
            // Step aside while the game runs (hiding, not closing: closing the last window would quit Claybox)
            NSApp.hide(nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
