import Foundation

/// Command-line helpers bundled inside Claybox.app/Contents/MacOS.
enum Helpers {
    static var macOS: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS", isDirectory: true) }
    /// The game engine (ScummVM with the neverhood engine and the Claybox HD patch, GPL)
    static var engine: URL { macOS.appendingPathComponent("claybox-engine") }
    /// Real-ESRGAN ncnn/Vulkan upscaler (MIT); its models stay in Resources/upscaler/models
    static var upscaler: URL { macOS.appendingPathComponent("realesrgan-ncnn-vulkan") }
}
