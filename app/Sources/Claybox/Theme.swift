import SwiftUI

// Claybox look: "warm studio" — dark umber ground, fired-clay accents.
// Everything here is original artwork; nothing comes from the game.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Theme {
    static let ground = Color(hex: 0x241812)
    static let panel = Color(hex: 0x33231B)
    static let panelDeep = Color(hex: 0x2C1E17)
    static let line = Color(hex: 0x3A2920)
    static let dashed = Color(hex: 0x9C6A4E)

    static let title = Color(hex: 0xF7E9D7)
    static let text = Color(hex: 0xF3E6D6)
    static let soft = Color(hex: 0xE8D3BF)
    static let muted = Color(hex: 0xCDB8A3)
    static let faint = Color(hex: 0xA8917E)
    static let accentText = Color(hex: 0xE8A57E)
    static let ok = Color(hex: 0x9FC27A)

    static let clay = Color(hex: 0xC8643B)
    static let olive = Color(hex: 0x7C8F5A)
    static let mustard = Color(hex: 0xD9A441)
    static let earth = Color(hex: 0x9C6A4E)

    static func display(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

/// A lump of clay: a soft blob with a lit top-left and a shaded bottom-right.
struct ClayBlob: View {
    var color: Color
    var width: CGFloat
    var height: CGFloat
    var rotation: Double = 0

    var body: some View {
        Ellipse()
            .fill(color)
            .overlay(
                Ellipse().fill(RadialGradient(colors: [Color.white.opacity(0.22), .clear],
                                              center: UnitPoint(x: 0.3, y: 0.25),
                                              startRadius: 0, endRadius: max(width, height) * 0.45))
            )
            .overlay(
                Ellipse().fill(RadialGradient(colors: [.clear, Color.black.opacity(0.38)],
                                              center: UnitPoint(x: 0.35, y: 0.3),
                                              startRadius: max(width, height) * 0.25,
                                              endRadius: max(width, height) * 0.7))
            )
            .frame(width: width, height: height)
            .rotationEffect(.degrees(rotation))
            .accessibilityHidden(true)
    }
}

struct ClayButtonStyle: ButtonStyle {
    var large = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body(large ? 18 : 16, .bold))
            .foregroundStyle(Theme.ground)
            .padding(.horizontal, large ? 30 : 26)
            .padding(.vertical, large ? 16 : 13)
            .frame(minHeight: 44)
            .background(
                Capsule().fill(Theme.clay)
                    .overlay(Capsule().strokeBorder(Color.black.opacity(0.18), lineWidth: 1).blendMode(.multiply))
                    .overlay(alignment: .bottom) {
                        Capsule().fill(Color.black.opacity(0.18)).frame(height: 4).padding(.horizontal, 10)
                    }
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .shadow(color: .black.opacity(large ? 0.3 : 0), radius: 12, y: 8)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body(16, .semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            .background(Capsule().strokeBorder(Color(hex: 0x5A4033), lineWidth: 2))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct PlainTextButtonStyle: ButtonStyle {
    var color: Color = Theme.muted
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body(16, .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct Footer: View {
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text("Made by")
                Link(destination: URL(string: "https://oxinstudio.com/apps/claybox/")!) {
                    Text("Oxin Studio").bold().foregroundStyle(Theme.soft)
                }
                .help("oxinstudio.com")
            }
            Spacer()
            HStack(spacing: 4) {
                Text("Free & open source · Powered by")
                Link("ScummVM", destination: URL(string: "https://www.scummvm.org")!)
                    .foregroundStyle(Color(hex: 0xF0B48E))
            }
        }
        .font(Theme.body(13))
        .foregroundStyle(Theme.faint)
        .padding(.horizontal, 28)
        .frame(height: 48)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}
