import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Optional HD videos, made on the user's Mac from the user's own game files:
//  1. the game engine writes each video's frames as PNGs (a few videos at a time)
//  2. each video is upscaled 2x with Real-ESRGAN's fast video model (GPU)
//  3. frames are stored as JPEGs in <hd-video>/<HASH>/<NNNNN>.jpg
// A video's folder only appears once all its frames are done, so a video is
// either fully HD or fully original — never mixed. Nothing is uploaded.

enum VideoEnhancer {
    struct Update: Sendable {
        let done: Int
        let total: Int
        let secondsLeft: Int?
    }

    static func run(engine: URL, configText: String, configURL: URL, logURL: URL,
                    workDir: URL, outDir: URL,
                    progress: @escaping @Sendable (Update) async -> Void) async throws {
        try await Task.detached(priority: .utility) {
            let fm = FileManager.default
            guard let res = Bundle.main.resourceURL else { throw ClayError.toolMissing("resources") }
            let tool = Helpers.upscaler
            let models = res.appendingPathComponent("upscaler/models")
            guard fm.isExecutableFile(atPath: tool.path) else { throw ClayError.toolMissing("upscaler") }

            let dumpDir = workDir.appendingPathComponent("video-frames", isDirectory: true)
            let upDir = workDir.appendingPathComponent("video-upscaled", isDirectory: true)
            for dir in [dumpDir, upDir] { try? fm.removeItem(at: dir) }
            try fm.createDirectory(at: dumpDir, withIntermediateDirectories: true)
            try fm.createDirectory(at: upDir, withIntermediateDirectories: true)
            try fm.createDirectory(at: outDir, withIntermediateDirectories: true)

            // 1. start the engine in "dump frames" mode — headless: never a window, never full screen
            let headless = configText
                .replacingOccurrences(of: "fullscreen=true", with: "fullscreen=false")
                // the windowless (dummy) display has no OpenGL: use the software renderer
                .replacingOccurrences(of: "gfx_mode=opengl", with: "gfx_mode=surfacesdl")
                + "\nclaybox_dump_videos=\(dumpDir.path)\n"
            try headless.write(to: configURL, atomically: true, encoding: .utf8)
            fm.createFile(atPath: logURL.path, contents: nil)
            let log = try FileHandle(forWritingTo: logURL)
            let dumper = Process()
            dumper.executableURL = engine
            dumper.arguments = ["--config=\(configURL.path)", "neverhood"]
            dumper.standardOutput = log
            dumper.standardError = log
            var env = ProcessInfo.processInfo.environment
            env["SDL_VIDEODRIVER"] = "dummy"   // no window, no display mode changes
            env["SDL_AUDIODRIVER"] = "dummy"
            dumper.environment = env
            dumper.qualityOfService = .background
            try dumper.run()
            defer { if dumper.isRunning { dumper.terminate() }; try? log.close() }

            var total = 0
            var done = (try? fm.contentsOfDirectory(atPath: outDir.path).filter { !$0.hasPrefix(".") && !$0.hasSuffix(".tmp") }.count) ?? 0
            let started = Date()
            var processedThisRun = 0
            var lastActivity = Date()

            while true {
                if Task.isCancelled { throw CancellationError() }
                if total == 0, let t = try? String(contentsOf: dumpDir.appendingPathComponent("total.txt"), encoding: .utf8) {
                    total = Int(t.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                }
                let ready = ((try? fm.contentsOfDirectory(atPath: dumpDir.path)) ?? [])
                    .filter { fm.fileExists(atPath: dumpDir.appendingPathComponent($0).appendingPathComponent("done").path) }
                    .sorted()

                if ready.isEmpty {
                    if !dumper.isRunning { break }
                    // watchdog: the frame dumper should always be making progress
                    let latest = ((try? fm.contentsOfDirectory(at: dumpDir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
                        .compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
                        .max() ?? .distantPast
                    if latest > lastActivity { lastActivity = latest }
                    if Date().timeIntervalSince(lastActivity) > 90 {
                        dumper.terminate()
                        throw ClayError.badData
                    }
                    try await Task.sleep(nanoseconds: 500_000_000)
                    continue
                }
                lastActivity = Date()

                for name in ready {
                    if Task.isCancelled { throw CancellationError() }
                    let frames = dumpDir.appendingPathComponent(name, isDirectory: true)
                    let final = outDir.appendingPathComponent(name, isDirectory: true)
                    defer { try? fm.removeItem(at: frames) }
                    if fm.fileExists(atPath: final.path) { continue }   // done in an earlier run
                    try? fm.removeItem(at: frames.appendingPathComponent("done"))
                    let count = (try? fm.contentsOfDirectory(atPath: frames.path).count) ?? 0
                    guard count > 0 else { continue }

                    // 2. upscale the whole video in one go (model loads once)
                    let up = upDir.appendingPathComponent(name, isDirectory: true)
                    try? fm.removeItem(at: up)
                    try fm.createDirectory(at: up, withIntermediateDirectories: true)
                    let p = Process()
                    p.executableURL = tool
                    // gentle on the GPU so the Mac stays responsive: one load/proc/save thread, small tiles
                    p.arguments = ["-i", frames.path, "-o", up.path, "-n", "realesr-animevideov3",
                                   "-s", "2", "-f", "png", "-m", models.path, "-t", "128", "-j", "1:1:1"]
                    p.qualityOfService = .utility
                    p.standardOutput = FileHandle.nullDevice
                    p.standardError = FileHandle.nullDevice
                    try p.run()
                    while p.isRunning {
                        if Task.isCancelled { p.terminate(); throw CancellationError() }
                        try await Task.sleep(nanoseconds: 200_000_000)
                    }
                    guard p.terminationStatus == 0 else { try? fm.removeItem(at: up); continue }

                    // 3. JPEG frames, then publish the folder in one step
                    let temp = outDir.appendingPathComponent(name + ".tmp", isDirectory: true)
                    try? fm.removeItem(at: temp)
                    try fm.createDirectory(at: temp, withIntermediateDirectories: true)
                    for file in (try? fm.contentsOfDirectory(atPath: up.path)) ?? [] where file.hasSuffix(".png") {
                        let src = up.appendingPathComponent(file)
                        let dst = temp.appendingPathComponent(String(file.dropLast(4)) + ".jpg")
                            try? writeJPEG(from: src, to: dst)
                    }
                    lastActivity = Date()
                    try? fm.removeItem(at: up)
                    try? fm.removeItem(at: final)
                    try fm.moveItem(at: temp, to: final)

                    done += 1
                    processedThisRun += 1
                    var left: Int?
                    if processedThisRun >= 3, total > done {
                        left = Int(Date().timeIntervalSince(started) / Double(processedThisRun) * Double(total - done))
                    }
                    await progress(Update(done: done, total: max(total, done), secondsLeft: left))
                }
            }
            try? fm.removeItem(at: dumpDir)
            try? fm.removeItem(at: upDir)
            await progress(Update(done: done, total: max(total, done), secondsLeft: nil))
        }.value
    }

    static func writeJPEG(from src: URL, to dst: URL, quality: Double = 0.85) throws {
        guard let source = CGImageSourceCreateWithURL(src as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let dest = CGImageDestinationCreateWithURL(dst as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw ClayError.imageWrite }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ClayError.imageWrite }
    }
}
