import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Optional HD characters & objects, made on the user's Mac from the user's own game files:
//  1. the game engine writes every animation frame (colors + a transparency mask + the palette)
//  2. colors are upscaled 2x with Real-ESRGAN's fast model (GPU); the mask is resampled smoothly
//  3. both are combined into RGBA frames: <hd-sprites>/<ANIM>/<FFFF>.png + palette.bin
// Nothing is uploaded.

enum SpriteEnhancer {
    struct Update: Sendable {
        let stage: String
        let done: Int
        let total: Int
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

            let dump = workDir.appendingPathComponent("sprites", isDirectory: true)
            let rgbDir = dump.appendingPathComponent("rgb"), maskDir = dump.appendingPathComponent("mask")
            let palDir = dump.appendingPathComponent("pal")
            let upDir = workDir.appendingPathComponent("sprites-upscaled", isDirectory: true)
            let maskUpDir = workDir.appendingPathComponent("sprites-mask-upscaled", isDirectory: true)
            let newOut = workDir.appendingPathComponent("hd-sprites-new", isDirectory: true)
            for dir in [dump, upDir, maskUpDir, newOut] { try? fm.removeItem(at: dir) }
            try fm.createDirectory(at: maskUpDir, withIntermediateDirectories: true)
            try fm.createDirectory(at: dump, withIntermediateDirectories: true)
            try fm.createDirectory(at: upDir, withIntermediateDirectories: true)
            try fm.createDirectory(at: newOut, withIntermediateDirectories: true)

            // 1. dump frames (headless engine run)
            await progress(Update(stage: "Reading animations…", done: 0, total: 0))
            let headless = configText.replacingOccurrences(of: "fullscreen=true", with: "fullscreen=false")
                // the windowless (dummy) display has no OpenGL: use the software renderer
                .replacingOccurrences(of: "gfx_mode=opengl", with: "gfx_mode=surfacesdl")
                + "\nclaybox_dump_sprites=\(dump.path)\n"
            try headless.write(to: configURL, atomically: true, encoding: .utf8)
            fm.createFile(atPath: logURL.path, contents: nil)
            let log = try FileHandle(forWritingTo: logURL)
            defer { try? log.close() }
            let dumper = Process()
            dumper.executableURL = engine
            dumper.arguments = ["--config=\(configURL.path)", "neverhood"]
            dumper.standardOutput = log
            dumper.standardError = log
            var env = ProcessInfo.processInfo.environment
            env["SDL_VIDEODRIVER"] = "dummy"
            env["SDL_AUDIODRIVER"] = "dummy"
            dumper.environment = env
            dumper.qualityOfService = .background
            try dumper.run()
            var lastCount = -1
            var lastChange = Date()
            while dumper.isRunning {
                if Task.isCancelled { dumper.terminate(); throw CancellationError() }
                let n = (try? fm.contentsOfDirectory(atPath: rgbDir.path).count) ?? 0
                if n != lastCount { lastCount = n; lastChange = Date() }
                if Date().timeIntervalSince(lastChange) > 90 { dumper.terminate(); throw ClayError.badData }
                await progress(Update(stage: "Reading animations…", done: n, total: 0))
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            guard fm.fileExists(atPath: dump.appendingPathComponent("done").path) else { throw ClayError.badData }
            let frames = ((try? fm.contentsOfDirectory(atPath: rgbDir.path)) ?? []).filter { $0.hasSuffix(".png") }
            let total = frames.count

            // 2. upscale all colour frames in one run (model loads once)
            let p = Process()
            p.executableURL = tool
            p.arguments = ["-i", rgbDir.path, "-o", upDir.path, "-n", "realesr-animevideov3",
                           "-s", "2", "-f", "png", "-m", models.path, "-t", "128", "-j", "1:1:1"]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            p.qualityOfService = .utility
            try p.run()
            while p.isRunning {
                if Task.isCancelled { p.terminate(); throw CancellationError() }
                let n = (try? fm.contentsOfDirectory(atPath: upDir.path).count) ?? 0
                await progress(Update(stage: "Sculpting characters…", done: n, total: total))
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            guard p.terminationStatus == 0 else { throw ClayError.badData }

            // 2b. upscale the masks too: the AI turns the original stair-stepped outlines into smooth curves
            let pm = Process()
            pm.executableURL = tool
            pm.arguments = ["-i", maskDir.path, "-o", maskUpDir.path, "-n", "realesr-animevideov3",
                            "-s", "2", "-f", "png", "-m", models.path, "-t", "128", "-j", "1:1:1"]
            pm.standardOutput = FileHandle.nullDevice
            pm.standardError = FileHandle.nullDevice
            pm.qualityOfService = .utility
            try pm.run()
            while pm.isRunning {
                if Task.isCancelled { pm.terminate(); throw CancellationError() }
                let n = (try? fm.contentsOfDirectory(atPath: maskUpDir.path).count) ?? 0
                await progress(Update(stage: "Smoothing edges…", done: n, total: total))
                try await Task.sleep(nanoseconds: 500_000_000)
            }

            // 3. combine colours + soft mask into RGBA frames
            for (i, file) in frames.enumerated() {
                if Task.isCancelled { throw CancellationError() }
                let base = String(file.dropLast(4))            // ANIM_FFFF
                let parts = base.split(separator: "_")
                guard parts.count == 2 else { continue }
                let anim = String(parts[0]), frame = String(parts[1])
                let animDir = newOut.appendingPathComponent(anim, isDirectory: true)
                if !fm.fileExists(atPath: animDir.path) {
                    try fm.createDirectory(at: animDir, withIntermediateDirectories: true)
                    try? fm.copyItem(at: palDir.appendingPathComponent(anim + ".bin"),
                                     to: animDir.appendingPathComponent("palette.bin"))
                }
                try? combine(color: upDir.appendingPathComponent(file),
                             mask: fm.fileExists(atPath: maskUpDir.appendingPathComponent(file).path)
                                ? maskUpDir.appendingPathComponent(file) : maskDir.appendingPathComponent(file),
                             to: animDir.appendingPathComponent(frame + ".png"))
                if i % 50 == 0 {
                    await progress(Update(stage: "Finishing touches…", done: i, total: total))
                }
            }
            try? fm.removeItem(at: outDir)
            try fm.moveItem(at: newOut, to: outDir)
            try? fm.removeItem(at: dump)
            try? fm.removeItem(at: upDir)
            try? fm.removeItem(at: maskUpDir)
            await progress(Update(stage: "Done", done: total, total: total))
        }.value
    }

    /// colour (already 2x) + mask (1x, resampled smoothly to 2x) → RGBA PNG
    static func combine(color: URL, mask: URL, to dst: URL) throws {
        guard let cs = CGImageSourceCreateWithURL(color as CFURL, nil),
              let colorImage = CGImageSourceCreateImageAtIndex(cs, 0, nil),
              let ms = CGImageSourceCreateWithURL(mask as CFURL, nil),
              let maskImage = CGImageSourceCreateImageAtIndex(ms, 0, nil) else { throw ClayError.imageWrite }
        let w = colorImage.width, h = colorImage.height
        let rgbSpace = ImageFiles.colorSpace
        guard let cctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                   space: rgbSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
              let mctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                   space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { throw ClayError.imageWrite }
        cctx.draw(colorImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        mctx.interpolationQuality = .high
        mctx.draw(maskImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let cdata = cctx.data?.assumingMemoryBound(to: UInt8.self),
              let mdata = mctx.data?.assumingMemoryBound(to: UInt8.self) else { throw ClayError.imageWrite }

        var out = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<(w * h) {
            // steepen the resampled mask a little: soft but not blurry edges
            let m = Double(mdata[i]) / 255
            let a = min(1, max(0, (m - 0.5) * 1.6 + 0.5))
            out[i * 4] = UInt8(Double(cdata[i * 4]) * a)
            out[i * 4 + 1] = UInt8(Double(cdata[i * 4 + 1]) * a)
            out[i * 4 + 2] = UInt8(Double(cdata[i * 4 + 2]) * a)
            out[i * 4 + 3] = UInt8(a * 255)
        }
        guard let provider = CGDataProvider(data: Data(out) as CFData),
              let rgba = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                                 space: rgbSpace, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                 provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { throw ClayError.imageWrite }
        try ImageFiles.write(rgba, to: dst)
    }
}
