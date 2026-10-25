import SwiftUI

// "Thirty candles": an original little clay character (Claybox's own mascot,
// not from the game) blowing out a "30" birthday candle on a clay cake.
// Plays on the Enhance screen while the HD backgrounds are being made.

struct BirthdayScene: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let cycle = t.truncatingRemainder(dividingBy: 5.0)
            // inhale 1.8–2.6s, blow 2.6–3.6s, flames relight after
            let inhale = cycle > 1.8 && cycle < 2.6
            let blow = cycle >= 2.6 && cycle < 3.6
            let out = cycle >= 3.3 && cycle < 4.2
            let flicker = sin(t * 11) * 0.06 + sin(t * 17) * 0.04

            ZStack {
                // table shadow
                Ellipse().fill(Color.black.opacity(0.35))
                    .frame(width: 380, height: 46)
                    .position(x: 215, y: 318)

                // cake
                cake.position(x: 290, y: 250)

                // the "30" candle
                Text("30")
                    .font(Theme.display(64))
                    .foregroundStyle(Color(hex: 0xF7E9D7))
                    .shadow(color: .black.opacity(0.35), radius: 0, x: 3, y: 4)
                    .position(x: 290, y: 165)

                // flames
                ForEach(0..<2, id: \.self) { i in
                    Flame()
                        .frame(width: 18, height: 30)
                        .scaleEffect(x: 1 - flicker, y: (out ? 0.05 : 1 + flicker * 2), anchor: .bottom)
                        .rotationEffect(.degrees(blow ? 38 : flicker * 40), anchor: .bottom)
                        .opacity(out ? 0 : 1)
                        .position(x: i == 0 ? 272 : 310, y: 116)
                }

                // smoke after the flames go out
                if out {
                    ForEach(0..<2, id: \.self) { i in
                        Circle().fill(Color.white.opacity(0.12))
                            .frame(width: 10, height: 10)
                            .position(x: (i == 0 ? 274 : 312) + CGFloat((cycle - 3.3) * 14),
                                      y: 112 - CGFloat((cycle - 3.3) * 50))
                    }
                }

                // breath
                if blow {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule().fill(Color(hex: 0xCDB8A3).opacity(0.5))
                            .frame(width: 26, height: 5)
                            .position(x: 150 + CGFloat((cycle - 2.6) * 120) + CGFloat(i * 8),
                                      y: 170 + CGFloat(i * 12) - 12)
                    }
                }

                mascot(inhale: inhale, blow: blow)
                    .position(x: 95, y: 230)
            }
            .frame(width: 420, height: 340)
        }
        .accessibilityElement()
        .accessibilityLabel("A little clay character blowing out a 30th birthday candle")
    }

    private var cake: some View {
        ZStack {
            // bottom tier
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.earth)
                .frame(width: 190, height: 90)
                .offset(y: 30)
            // top tier
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.clay)
                .frame(width: 150, height: 70)
                .offset(y: -36)
            // frosting drips
            HStack(spacing: 6) {
                ForEach(0..<6, id: \.self) { i in
                    Capsule().fill(Theme.mustard)
                        .frame(width: 18, height: i % 2 == 0 ? 26 : 18)
                }
            }
            .offset(y: -62)
            RoundedRectangle(cornerRadius: 10).fill(Theme.mustard)
                .frame(width: 154, height: 14)
                .offset(y: -70)
            // dots
            HStack(spacing: 22) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle().fill(Color(hex: 0xF7E9D7).opacity(0.85)).frame(width: 9, height: 9)
                }
            }
            .offset(y: 38)
        }
        .overlay(
            Rectangle()
                .fill(LinearGradient(colors: [Color.white.opacity(0.12), Color.black.opacity(0.22)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .blendMode(BlendMode.overlay)
                .allowsHitTesting(false)
        )
    }

    /// The Claybox mascot: a round lump of olive clay with a little sprout.
    private func mascot(inhale: Bool, blow: Bool) -> some View {
        ZStack {
            // sprout
            Capsule().fill(Color(hex: 0x6F8A4A)).frame(width: 5, height: 22).offset(y: -72)
            Ellipse().fill(Color(hex: 0x9FC27A)).frame(width: 22, height: 12)
                .rotationEffect(.degrees(-30)).offset(x: 10, y: -84)
            Ellipse().fill(Color(hex: 0x9FC27A)).frame(width: 18, height: 10)
                .rotationEffect(.degrees(30)).offset(x: -9, y: -80)

            ClayBlob(color: Theme.olive, width: inhale ? 136 : 128, height: inhale ? 132 : 122)

            // cheeks
            Circle().fill(Theme.clay.opacity(blow ? 0.75 : 0.45))
                .frame(width: blow ? 26 : 18, height: blow ? 26 : 18)
                .offset(x: 34, y: 14)
            Circle().fill(Theme.clay.opacity(blow ? 0.6 : 0.35))
                .frame(width: blow ? 22 : 16, height: blow ? 22 : 16)
                .offset(x: -18, y: 14)

            // eyes (squeezed shut while blowing)
            Group {
                if blow {
                    Capsule().fill(Theme.ground).frame(width: 14, height: 4).offset(x: 6, y: -14)
                    Capsule().fill(Theme.ground).frame(width: 14, height: 4).offset(x: 34, y: -14)
                } else {
                    Circle().fill(Theme.ground).frame(width: 12, height: 14).offset(x: 6, y: -14)
                    Circle().fill(Theme.ground).frame(width: 12, height: 14).offset(x: 34, y: -14)
                    Circle().fill(Color.white.opacity(0.8)).frame(width: 4, height: 4).offset(x: 8, y: -17)
                    Circle().fill(Color.white.opacity(0.8)).frame(width: 4, height: 4).offset(x: 36, y: -17)
                }
            }

            // mouth
            if blow {
                Circle().fill(Theme.ground).frame(width: 12, height: 12).offset(x: 46, y: 12)
            } else {
                Capsule().fill(Theme.ground).frame(width: 16, height: 5).offset(x: 22, y: 14)
            }

            // little arms
            Capsule().fill(Theme.olive).frame(width: 34, height: 14)
                .rotationEffect(.degrees(-20)).offset(x: 62, y: 34)
            Capsule().fill(Theme.olive).frame(width: 30, height: 14)
                .rotationEffect(.degrees(25)).offset(x: -62, y: 36)
        }
    }
}

struct Flame: View {
    var body: some View {
        ZStack {
            Ellipse().fill(RadialGradient(colors: [Color(hex: 0xFFE8A3), Color(hex: 0xF2A03D), Color(hex: 0xC8643B).opacity(0)],
                                          center: UnitPoint(x: 0.5, y: 0.65), startRadius: 1, endRadius: 18))
            Ellipse().fill(Color(hex: 0xFFF6D8)).frame(width: 6, height: 10).offset(y: 6)
        }
        .blendMode(.screen)
    }
}
