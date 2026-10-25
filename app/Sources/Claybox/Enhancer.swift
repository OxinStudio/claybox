import Foundation

// Builds the HD backgrounds on the user's Mac, from the user's own disc:
//  1. extract every full-screen background from the game files (PNG, original size)
//  2. upscale each one 4x with Real-ESRGAN (ncnn/Vulkan, on the Mac's GPU)
//  3. resample to exactly 2x and drop it into the HD folder as <HASH>.png
// Images are installed one at a time, so the game can already be played:
// each scene shows in HD as soon as its image is ready. Re-running resumes.
// Nothing is downloaded or uploaded.

enum Enhancer {
    struct Update: Sendable {
        let stage: String
        let done: Int
        let total: Int
        let secondsLeft: Int?
    }

    static let archives = ["i.blb", "hd.blb", "t.blb", "c.blb"]

    static func run(dataFolder: URL, workDir: URL, hdDir: URL,
                    progress: @escaping @Sendable (Update) async -> Void) async throws {
        try await Task.detached(priority: .utility) {
            let fm = FileManager.default
            let extracted = workDir.appendingPathComponent("original", isDirectory: true)
            let scratch = workDir.appendingPathComponent("scratch", isDirectory: true)
            for dir in [extracted, scratch, hdDir] {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }

            guard let res = Bundle.main.resourceURL else { throw ClayError.toolMissing("resources") }
            let tool = Helpers.upscaler
            let models = res.appendingPathComponent("upscaler/models")
            guard fm.isExecutableFile(atPath: tool.path) else { throw ClayError.toolMissing("upscaler") }

            // 1. Extract (skipping scenes that are already done)
            await progress(Update(stage: "Reading your disc…", done: 0, total: 0, secondsLeft: nil))
            var jobs: [(name: String, width: Int, height: Int)] = []
            var alreadyDone = 0
            for archiveName in archives {
                guard let url = GameDisc.file(named: archiveName, in: dataFolder) else { continue }
                let archive = try BLBArchive(url: url)
                for e in archive.entries where e.type == 2 && e.size >= 640 * 480 {
                    try Task.checkCancellation()
                    let name = String(format: "%08X", e.hash)
                    let original = extracted.appendingPathComponent(name + ".png")
                    if fm.fileExists(atPath: hdDir.appendingPathComponent(name + ".png").path) {
                        alreadyDone += 1
                        continue
                    }
                    if let (w, h) = ImageFiles.size(of: original) {
                        jobs.append((name, w, h))
                        continue
                    }
                    guard let img = Bitmap.decode(try archive.load(e)), img.width >= 640, img.height >= 480 else { continue }
                    try ImageFiles.writePNG(img, to: original)
                    jobs.append((name, img.width, img.height))
                }
            }
            if jobs.isEmpty && alreadyDone == 0 { throw ClayError.notTheGame }
            let total = jobs.count + alreadyDone

            // 2 + 3. Upscale and install, one scene at a time
            let started = Date()
            for (i, job) in jobs.enumerated() {
                try Task.checkCancellation()
                var left: Int?
                if i >= 2 {
                    left = Int(Date().timeIntervalSince(started) / Double(i) * Double(jobs.count - i))
                }
                await progress(Update(stage: "Sculpting in HD…", done: alreadyDone + i, total: total, secondsLeft: left))

                let src = extracted.appendingPathComponent(job.name + ".png")
                let big = scratch.appendingPathComponent(job.name + ".png")
                let p = Process()
                p.executableURL = tool
                p.arguments = ["-i", src.path, "-o", big.path, "-n", "realesrgan-x4plus",
                               "-s", "4", "-f", "png", "-m", models.path, "-j", "1:1:1"]
                p.qualityOfService = .utility
                p.standardOutput = FileHandle.nullDevice
                p.standardError = FileHandle.nullDevice
                try p.run()
                while p.isRunning {
                    if Task.isCancelled { p.terminate(); throw CancellationError() }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                guard p.terminationStatus == 0, fm.fileExists(atPath: big.path) else { continue }

                // write next to the final name, then rename, so the game never reads half a file
                let temp = hdDir.appendingPathComponent(job.name + ".tmp.png")
                try ImageFiles.resize(big, to: temp, width: job.width * 2, height: job.height * 2)
                let final = hdDir.appendingPathComponent(job.name + ".png")
                try? fm.removeItem(at: final)
                try fm.moveItem(at: temp, to: final)
                try? fm.removeItem(at: big)
                try? fm.removeItem(at: src)
            }
            await progress(Update(stage: "Done", done: total, total: total, secondsLeft: nil))
            try? fm.removeItem(at: scratch)
        }.value
    }
}
