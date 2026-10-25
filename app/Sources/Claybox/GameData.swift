import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Reads background images from the user's own game files (BLB archives).
// Formats follow ScummVM's neverhood engine (GPL); the decompressor is a
// port of the PKWARE DCL "implode" decoder (after Mark Adler's blast.c).

enum ClayError: LocalizedError {
    case badData
    case notTheGame
    case mountFailed(String)
    case toolMissing(String)
    case imageWrite

    var errorDescription: String? {
        switch self {
        case .badData: return "Some game data could not be read."
        case .notTheGame: return "This doesn’t look like a disc of The Neverhood. Claybox needs the original Windows CD (or an ISO made from it)."
        case .mountFailed(let why): return "Couldn’t open the disc image. \(why)"
        case .toolMissing(let name): return "A part of Claybox is missing (\(name)). Please reinstall the app."
        case .imageWrite: return "Couldn’t save an image."
        }
    }
}

// MARK: - DCL decompression

private struct BitReader {
    let data: [UInt8]
    var pos = 0
    var buf = 0
    var cnt = 0

    mutating func bits(_ n: Int) throws -> Int {
        while cnt < n {
            guard pos < data.count else { throw ClayError.badData }
            buf |= Int(data[pos]) << cnt
            pos += 1
            cnt += 8
        }
        let v = buf & ((1 << n) - 1)
        buf >>= n
        cnt -= n
        return v
    }
}

private struct Huffman {
    var count: [Int]
    var symbol: [Int]

    init(compact: [Int]) {
        var lengths: [Int] = []
        for b in compact { lengths += Array(repeating: b & 15, count: (b >> 4) + 1) }
        let maxLen = lengths.max() ?? 1
        count = Array(repeating: 0, count: maxLen + 1)
        for l in lengths { count[l] += 1 }
        var offs = Array(repeating: 0, count: maxLen + 2)
        for l in 1...maxLen { offs[l + 1] = offs[l] + count[l] }
        symbol = Array(repeating: 0, count: lengths.count)
        for (s, l) in lengths.enumerated() where l != 0 {
            symbol[offs[l]] = s
            offs[l] += 1
        }
    }

    func decode(_ r: inout BitReader) throws -> Int {
        var code = 0, first = 0, index = 0
        for l in 1..<count.count {
            code |= (try r.bits(1)) ^ 1
            let c = count[l]
            if code < first + c { return symbol[index + code - first] }
            index += c
            first += c
            first <<= 1
            code <<= 1
        }
        throw ClayError.badData
    }
}

enum DCL {
    private static let lenCode = Huffman(compact: [2, 35, 36, 53, 38, 23])
    private static let distCode = Huffman(compact: [2, 20, 53, 230, 247, 151, 248])
    private static let base = [3, 2, 4, 5, 6, 7, 8, 9, 10, 12, 16, 24, 40, 72, 136, 264]
    private static let extra = [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8]

    static func decompress(_ src: [UInt8], outSize: Int) throws -> [UInt8] {
        var r = BitReader(data: src)
        let literalMode = try r.bits(8)
        let dictBits = try r.bits(8)
        guard literalMode == 0, (4...6).contains(dictBits) else { throw ClayError.badData }
        var out: [UInt8] = []
        out.reserveCapacity(outSize)
        while out.count < outSize {
            if try r.bits(1) == 1 {
                let s = try lenCode.decode(&r)
                let len = base[s] + (try r.bits(extra[s]))
                if len == 519 { break }
                let shift = len == 2 ? 2 : dictBits
                let dist = (try distCode.decode(&r) << shift) + (try r.bits(shift)) + 1
                guard dist <= out.count else { throw ClayError.badData }
                let start = out.count - dist
                for i in 0..<len { out.append(out[start + i]) }
            } else {
                out.append(UInt8(try r.bits(8)))
            }
        }
        return out
    }
}

// MARK: - BLB archives

struct BLBEntry {
    let hash: UInt32
    let type: UInt8
    let compression: UInt8
    let offset: UInt64
    let diskSize: Int
    let size: Int
}

private extension Array where Element == UInt8 {
    func u16(_ p: Int) -> Int { Int(self[p]) | Int(self[p + 1]) << 8 }
    func s16(_ p: Int) -> Int { Int(Int16(bitPattern: UInt16(u16(p)))) }
    func u32(_ p: Int) -> UInt32 {
        UInt32(self[p]) | UInt32(self[p + 1]) << 8 | UInt32(self[p + 2]) << 16 | UInt32(self[p + 3]) << 24
    }
}

final class BLBArchive {
    let handle: FileHandle
    let entries: [BLBEntry]

    init(url: URL) throws {
        handle = try FileHandle(forReadingFrom: url)
        try handle.seek(toOffset: 0)
        let header = [UInt8](try handle.read(upToCount: 16) ?? Data())
        guard header.count == 16, header.u32(0) == 0x2004940, header.u16(4) == 7 else { throw ClayError.badData }
        let n = Int(header.u32(12))
        let hashes = [UInt8](try handle.read(upToCount: 4 * n) ?? Data())
        let records = [UInt8](try handle.read(upToCount: 20 * n) ?? Data())
        guard hashes.count == 4 * n, records.count == 20 * n else { throw ClayError.badData }
        entries = (0..<n).map { i in
            let r = i * 20
            return BLBEntry(hash: hashes.u32(i * 4),
                            type: records[r],
                            compression: records[r + 1],
                            offset: UInt64(records.u32(r + 8)),
                            diskSize: Int(records.u32(r + 12)),
                            size: Int(records.u32(r + 16)))
        }
    }

    deinit { try? handle.close() }

    func load(_ e: BLBEntry) throws -> [UInt8] {
        try handle.seek(toOffset: e.offset)
        let raw = [UInt8](try handle.read(upToCount: e.diskSize) ?? Data())
        guard raw.count == e.diskSize else { throw ClayError.badData }
        return e.compression == 1 ? raw : try DCL.decompress(raw, outSize: e.size)
    }
}

// MARK: - Bitmaps

struct RGBImage {
    let width: Int
    let height: Int
    var rgba: [UInt8]
}

enum Bitmap {
    /// Decodes an 8-bit bitmap resource that carries its own palette into RGBA.
    static func decode(_ d: [UInt8]) -> RGBImage? {
        guard d.count >= 2 else { return nil }
        let flags = d.u16(0)
        var p = 2
        var w = 1, h = 1
        var paletteOffset: Int?
        if flags & 2 != 0 { guard p + 4 <= d.count else { return nil }; w = d.u16(p); h = d.u16(p + 2); p += 4 }
        if flags & 4 != 0 { p += 4 }
        if flags & 8 != 0 { paletteOffset = p; p += 1024 }
        guard flags & 16 != 0, let pal = paletteOffset, pal + 1024 <= d.count, w > 0, h > 0 else { return nil }

        var index = [UInt8](repeating: 0, count: w * h)
        if flags & 1 != 0 {
            var y = 0
            guard p + 4 <= d.count else { return nil }
            var rows = d.s16(p), chunks = d.s16(p + 2)
            p += 4
            while rows > 0 {
                if chunks == 0 {
                    y += rows
                } else {
                    for _ in 0..<rows {
                        for _ in 0..<chunks {
                            guard p + 4 <= d.count else { return nil }
                            let skip = d.s16(p), copy = d.s16(p + 2)
                            p += 4
                            guard p + copy <= d.count else { return nil }
                            if y < h {
                                for i in 0..<copy where skip + i < w && skip + i >= 0 {
                                    index[y * w + skip + i] = d[p + i]
                                }
                            }
                            p += copy
                        }
                        y += 1
                    }
                }
                guard p + 4 <= d.count else { break }
                rows = d.s16(p); chunks = d.s16(p + 2)
                p += 4
            }
        } else {
            guard p + w * h <= d.count else { return nil }
            for i in 0..<(w * h) { index[i] = d[p + i] }
        }

        var rgba = [UInt8](repeating: 255, count: w * h * 4)
        for i in 0..<(w * h) {
            let c = pal + Int(index[i]) * 4
            rgba[i * 4] = d[c]
            rgba[i * 4 + 1] = d[c + 1]
            rgba[i * 4 + 2] = d[c + 2]
        }
        return RGBImage(width: w, height: h, rgba: rgba)
    }
}

// MARK: - PNG in / out

enum ImageFiles {
    static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    static func writePNG(_ img: RGBImage, to url: URL) throws {
        guard let provider = CGDataProvider(data: Data(img.rgba) as CFData),
              let cg = CGImage(width: img.width, height: img.height, bitsPerComponent: 8, bitsPerPixel: 32,
                               bytesPerRow: img.width * 4, space: colorSpace,
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { throw ClayError.imageWrite }
        try write(cg, to: url)
    }

    static func write(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw ClayError.imageWrite }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw ClayError.imageWrite }
    }

    static func size(of url: URL) -> (Int, Int)? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (w, h)
    }

    /// High-quality resample of `src` to exactly width × height.
    static func resize(_ src: URL, to dst: URL, width: Int, height: Int) throws {
        guard let source = CGImageSourceCreateWithURL(src as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw ClayError.imageWrite }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let out = ctx.makeImage() else { throw ClayError.imageWrite }
        try write(out, to: dst)
    }
}

// MARK: - Finding the game on a disc

enum GameDisc {
    /// Looks for the game's DATA folder (case-insensitive) below `root`.
    static func dataFolder(in root: URL) -> URL? {
        let fm = FileManager.default
        if hasGameFiles(root) { return root }
        guard let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { return nil }
        for item in items where item.lastPathComponent.lowercased() == "data" {
            if hasGameFiles(item) { return item }
        }
        return nil
    }

    static func hasGameFiles(_ folder: URL) -> Bool {
        file(named: "hd.blb", in: folder) != nil && file(named: "i.blb", in: folder) != nil
    }

    static func file(named name: String, in folder: URL) -> URL? {
        guard let items = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return nil }
        return items.first { $0.lastPathComponent.lowercased() == name.lowercased() }
    }
}
