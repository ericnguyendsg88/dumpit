import SwiftUI

/// Pip's mouth: a stroked curve that only gapes when a word lands. Drawn in
/// normalised coordinates so it can be framed anywhere on the bin's face.
struct PipSmile: Shape {
    var openness: Double
    var isResting: Bool

    var animatableData: Double {
        get { openness }
        set { openness = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let open = min(max(openness, 0), 1)
        let inset = rect.width * (0.10 - 0.08 * open)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - inset, y: rect.midY),
            control: CGPoint(
                x: rect.midX,
                y: rect.midY + (isResting ? 0 : rect.height * (0.85 + 2.4 * open))
            )
        )
        return path
    }
}

/// Pip: a small bin that keeps your thoughts. The lid lifts when he eats.
struct PipMascot: View {
    var mood: Mood = .happy
    var size: CGFloat = 92
    /// 0 shut, 1 wide open. Drives the mouth and how far the lid tips.
    var chew: Double = 0

    enum Mood {
        case happy, cheering, resting, eating
    }

    private var lift: Double {
        mood == .cheering ? 1 : min(max(chew, 0), 1)
    }

    private var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [.white, ClearTheme.mint],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            lid

            can
                .offset(y: size * 0.26)
        }
        .frame(width: size, height: size * 0.78)
        .accessibilityLabel("Pip, your DumpIt bin")
    }

    private var lid: some View {
        VStack(spacing: size * 0.035) {
            Capsule()
                .fill(bodyGradient)
                .frame(width: size * 0.26, height: size * 0.075)
            Capsule()
                .fill(bodyGradient)
                .frame(width: size * 0.86, height: size * 0.12)
        }
        .overlay {
            // Keeps the lid readable against the teal fill behind it.
            Capsule()
                .stroke(ClearTheme.forest.opacity(0.16), lineWidth: max(1, size * 0.014))
                .frame(width: size * 0.86, height: size * 0.12)
                .offset(y: size * 0.055)
        }
        .rotationEffect(.degrees(-20 * lift), anchor: .bottomLeading)
        .offset(x: size * 0.06 * lift, y: -size * 0.06 * lift)
        .animation(.spring(response: 0.26, dampingFraction: 0.6), value: lift)
    }

    private var can: some View {
        ZStack {
            TrashBody()
                .fill(bodyGradient)
                .overlay {
                    TrashBody()
                        .stroke(ClearTheme.forest.opacity(0.14), lineWidth: max(1, size * 0.014))
                }

            // Ribs down the sides of the can.
            HStack(spacing: size * 0.30) {
                ridge
                ridge
            }
            .offset(y: size * 0.06)

            face
        }
        .frame(width: size * 0.80, height: size * 0.58)
    }

    private var ridge: some View {
        Capsule()
            .fill(ClearTheme.tealDark.opacity(0.13))
            .frame(width: size * 0.028, height: size * 0.20)
    }

    private var face: some View {
        VStack(spacing: size * 0.045) {
            HStack(spacing: size * 0.17) {
                Circle().fill(ClearTheme.forest).frame(width: size * 0.06)
                Circle().fill(ClearTheme.forest).frame(width: size * 0.06)
            }

            PipSmile(openness: chew, isResting: mood == .resting)
                .stroke(
                    ClearTheme.forest,
                    style: StrokeStyle(lineWidth: max(2, size * 0.028), lineCap: .round)
                )
                .frame(width: size * 0.24, height: size * 0.07)
        }
        .offset(y: -size * 0.02)
    }
}

struct GlowingClearProgressBar: View {
    let value: Double
    let isActive: Bool
    var barHeight: CGFloat = 34
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var chomping = false
    @State private var chompTask: Task<Void, Never>?
    /// 0 → 1 as the overnight pile charges in at the start of a session.
    @State private var rotCharge: Double = 0
    /// Flares to 1 as the pile lands, then decays — the "it piled up" surge.
    @State private var chargeGlow: Double = 0

    /// Ornaments shrink with the bar so the compact iOS header keeps the same
    /// proportions as the full-size one.
    private var scale: CGFloat { barHeight / 34 }

    /// Big enough to read as a face, even on the 14pt iOS bar.
    private var mascotSize: CGFloat { max(26, barHeight * 1.9) }

    var body: some View {
        HStack(spacing: 14 * max(scale, 0.6)) {
            TimelineView(
                // Never fully paused while visible: the rot has to look alive
                // even when you have stopped typing.
                .animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)
            ) { timeline in
                let seconds = timeline.date.timeIntervalSinceReferenceDate
                let alive = !reduceMotion
                let breath = alive ? (sin(seconds * .pi * 2 / 3.2) + 1) / 2 : 0.0
                let sweep = reduceMotion || !isActive
                    ? 0.5
                    : seconds.truncatingRemainder(dividingBy: 2.6) / 2.6

                GeometryReader { proxy in
                    // Early words are worth more visually than they are
                    // proportionally — a flat first 80 words reads as broken.
                    let clamped = min(max(value, 0), 1)
                    let eased = clamped == 0 ? 0 : pow(clamped, 0.62)
                    let fillWidth = proxy.size.width * eased
                    let blendWidth = min(52, max(14, fillWidth * 0.45))
                    let beamWidth = min(max(fillWidth * 1.15, 130), 230)

                    let chargeWidth = proxy.size.width * rotCharge
                    let ooze = alive ? sin(seconds * 0.55) * 0.22 : 0

                    ZStack(alignment: .leading) {
                        // Empty trough behind everything.
                        Capsule()
                            .fill(ClearTheme.creamDeep.opacity(0.75))

                        // The rot pile: everything still cluttering your head.
                        // It charges in from the left when a session opens and
                        // keeps oozing while it sits there.
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        ClearTheme.rot,
                                        ClearTheme.rotDeep,
                                        ClearTheme.rot
                                    ],
                                    startPoint: UnitPoint(x: -0.35 + ooze, y: 0),
                                    endPoint: UnitPoint(x: 1.05 + ooze, y: 1)
                                )
                            )
                            .overlay {
                                TrashSpecks(
                                    fillWidth: fillWidth,
                                    chargeWidth: chargeWidth,
                                    barHeight: barHeight,
                                    width: proxy.size.width,
                                    seconds: seconds,
                                    animates: alive
                                )
                            }
                            .overlay {
                                // Sickly gleam crawling along the pile.
                                let sheenWidth = max(70, proxy.size.width * 0.28)
                                let crawl = alive
                                    ? seconds.truncatingRemainder(dividingBy: 3.4) / 3.4
                                    : 0.5

                                LinearGradient(
                                    colors: [
                                        .clear,
                                        ClearTheme.mint.opacity(0.10 + chargeGlow * 0.30),
                                        .white.opacity(0.16 + chargeGlow * 0.34),
                                        ClearTheme.mint.opacity(0.10 + chargeGlow * 0.30),
                                        .clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: sheenWidth)
                                .blur(radius: 9)
                                .offset(
                                    x: -proxy.size.width / 2 - sheenWidth / 2
                                        + CGFloat(crawl) * (proxy.size.width + sheenWidth)
                                )
                            }
                            .mask(alignment: .leading) {
                                Rectangle().frame(width: max(0, chargeWidth))
                            }
                            .overlay {
                                Capsule().stroke(.white.opacity(0.55), lineWidth: 1.5)
                            }
                            .clipShape(Capsule())
                            // Layered pulse: a steady breath plus a hard flare
                            // while the overnight pile charges in.
                            .shadow(
                                color: ClearTheme.rotDeep.opacity(0.24 + (alive ? breath * 0.30 : 0.06) + chargeGlow * 0.40),
                                radius: 8 + (alive ? breath * 9 : 0) + chargeGlow * 16
                            )
                            .shadow(
                                color: ClearTheme.rot.opacity((alive ? breath * 0.22 : 0) + chargeGlow * 0.45),
                                radius: 5 + breath * 8 + chargeGlow * 22
                            )
                            .scaleEffect(y: 1 + chargeGlow * 0.12)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        ClearTheme.tealDark,
                                        ClearTheme.teal,
                                        ClearTheme.mint
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: fillWidth)
                            .overlay {
                                if isActive && value > 0 && !reduceMotion {
                                    LinearGradient(
                                        colors: [
                                            .clear,
                                            .white.opacity(0.08),
                                            .white.opacity(0.26),
                                            .white.opacity(0.52),
                                            .white.opacity(0.26),
                                            .white.opacity(0.08),
                                            .clear
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .frame(width: beamWidth)
                                    .blur(radius: 10)
                                    .offset(
                                        x: -fillWidth - beamWidth / 2
                                            + CGFloat(sweep) * (fillWidth * 2 + beamWidth)
                                    )
                                }
                            }
                            // Soften the leading edge so green dissolves into
                            // the rot instead of butting against it.
                            .mask {
                                LinearGradient(
                                    stops: [
                                        .init(color: .black, location: 0),
                                        .init(
                                            color: .black,
                                            location: fillWidth > 0
                                                ? max(0, (fillWidth - blendWidth) / fillWidth)
                                                : 1
                                        ),
                                        .init(color: .black.opacity(0.35), location: 0.93),
                                        .init(color: .clear, location: 1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                            .clipShape(Capsule())
                            .shadow(
                                color: ClearTheme.teal.opacity(
                                    isActive ? 0.24 + breath * 0.34 : 0.16
                                ),
                                radius: isActive ? 10 + breath * 12 : 3
                            )
                            .shadow(
                                color: ClearTheme.mint.opacity(isActive ? 0.16 + breath * 0.24 : 0),
                                radius: 7 + breath * 9
                            )
                            .scaleEffect(y: isActive ? 1 + breath * 0.045 : 1)
                            .animation(.spring(response: 0.42, dampingFraction: 0.76), value: value)

                        // Pip rides the leading edge, chewing through the pile.
                        ZStack {
                            Circle()
                                .fill(ClearTheme.mint.opacity(0.55))
                                .frame(
                                    width: mascotSize * (1.05 + CGFloat(breath) * 0.12),
                                    height: mascotSize * (1.05 + CGFloat(breath) * 0.12)
                                )
                                .blur(radius: 9 * scale)

                            // The mouth is shut by default and gapes for one
                            // bite each time a word lands.
                            PipMascot(
                                mood: value >= 1 ? .cheering : .happy,
                                size: mascotSize,
                                chew: chomping ? 1 : 0
                            )
                            .scaleEffect(chomping ? 1.12 : 1)
                            .animation(.spring(response: 0.24, dampingFraction: 0.55), value: chomping)
                        }
                        .position(
                            x: min(max(fillWidth, mascotSize * 0.42), proxy.size.width - mascotSize * 0.30),
                            y: barHeight / 2
                        )
                        .animation(.spring(response: 0.42, dampingFraction: 0.76), value: value)
                    }
                }
            }
            .frame(height: barHeight)
            .onAppear {
                guard !reduceMotion else {
                    rotCharge = 1
                    return
                }
                // Overnight build-up: the pile floods in, glows hard as it
                // lands, then settles to its idle simmer.
                withAnimation(.spring(response: 0.95, dampingFraction: 0.72)) {
                    rotCharge = 1
                }
                withAnimation(.easeOut(duration: 0.45)) {
                    chargeGlow = 1
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    withAnimation(.easeInOut(duration: 1.5)) {
                        chargeGlow = 0
                    }
                }
            }
            .onChange(of: value) { _, _ in
                guard !reduceMotion else { return }
                chomping = true
                chompTask?.cancel()
                chompTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(240))
                    guard !Task.isCancelled else { return }
                    chomping = false
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's Clear State progress")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

/// Debris scattered through the rot pile. Each speck pops out of existence as
/// the fill edge reaches it, so the bar visibly clears as you write.
struct TrashSpecks: View {
    let fillWidth: CGFloat
    /// How far the pile has charged in — specks appear as the rot spreads.
    let chargeWidth: CGFloat
    let barHeight: CGFloat
    let width: CGFloat
    let seconds: Double
    let animates: Bool

    /// Fixed layout — random per redraw would make the pile crawl.
    private static let layout: [(x: Double, y: Double, size: Double, angle: Double)] = [
        (0.06, 0.34, 0.30, 12), (0.11, 0.68, 0.22, -20), (0.17, 0.42, 0.26, 34),
        (0.23, 0.70, 0.20, -8), (0.29, 0.32, 0.28, 22), (0.35, 0.62, 0.24, -30),
        (0.41, 0.38, 0.22, 16), (0.47, 0.66, 0.30, -14), (0.53, 0.34, 0.24, 28),
        (0.59, 0.64, 0.20, -22), (0.65, 0.40, 0.28, 8), (0.71, 0.68, 0.22, -34),
        (0.77, 0.34, 0.26, 20), (0.83, 0.60, 0.24, -12), (0.89, 0.42, 0.28, 30),
        (0.95, 0.66, 0.20, -18)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(Self.layout.enumerated()), id: \.offset) { index, speck in
                let x = speck.x * width
                let eaten = x <= fillWidth + barHeight * 0.25
                let piled = x <= chargeWidth
                let side = barHeight * speck.size
                // Each speck stews on its own phase so the pile never pulses
                // in unison.
                let bob = animates
                    ? sin(seconds * 1.5 + Double(index) * 0.9) * Double(barHeight) * 0.07
                    : 0
                let squirm = animates
                    ? sin(seconds * 1.1 + Double(index) * 1.7) * 7
                    : 0

                RoundedRectangle(cornerRadius: side * 0.32, style: .continuous)
                    .fill(ClearTheme.rotSpeck.opacity(0.55))
                    .frame(width: side, height: side)
                    .rotationEffect(.degrees(speck.angle + squirm))
                    .position(x: x, y: barHeight * speck.y + bob)
                    .opacity(eaten || !piled ? 0 : 1)
                    .scaleEffect(eaten ? 0.15 : (piled ? 1 : 0.4))
                    .animation(.easeOut(duration: 0.32), value: eaten)
                    .animation(.easeOut(duration: 0.3), value: piled)
            }
        }
        .allowsHitTesting(false)
    }
}

struct ClearButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                configuration.isPressed ? ClearTheme.tealDark : ClearTheme.teal,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Tapered can body for the bin icon.
struct TrashBody: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.10
        let foot = rect.height * 0.10
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - foot))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - inset * 2, y: rect.maxY),
            control: CGPoint(x: rect.maxX - inset, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + inset * 2, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + inset, y: rect.maxY - foot),
            control: CGPoint(x: rect.minX + inset, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

/// A bin whose lid swings open. Shapes inherit the surrounding foreground
/// style, so it tints itself to whatever it sits on.
struct TrashCanIcon: View {
    var isOpen: Bool
    var size: CGFloat = 18

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: size * 0.05) {
                Capsule()
                    .frame(width: size * 0.34, height: size * 0.09)
                Capsule()
                    .frame(width: size * 0.96, height: size * 0.13)
            }
            .rotationEffect(.degrees(isOpen ? -34 : 0), anchor: .bottomLeading)
            .offset(
                x: isOpen ? size * 0.12 : 0,
                y: isOpen ? -size * 0.10 : 0
            )

            TrashBody()
                .frame(width: size * 0.78, height: size * 0.66)
                .offset(y: size * 0.32)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.38, dampingFraction: 0.6), value: isOpen)
        .accessibilityHidden(true)
    }
}

/// A sheet of paper that balls up. At `crumple` 0 it is a clean page; as it
/// rises the outline blends toward a lumpy ball with jagged, deterministic
/// creases (random-per-frame noise would boil).
struct CrumpledPaper: Shape {
    var crumple: Double

    var animatableData: Double {
        get { crumple }
        set { crumple = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let amount = min(max(crumple, 0), 1)
        let steps = 30
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()

        for index in 0..<steps {
            let t = Double(index) / Double(steps)
            let edge = Self.pointOnRect(rect, t: t)
            let angle = t * 2 * .pi - .pi / 2
            let ball = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            let blend = amount * 0.78
            var x = edge.x + (ball.x - edge.x) * blend
            var y = edge.y + (ball.y - edge.y) * blend

            // Push each vertex in or out along its own radius to make creases.
            let dx = x - center.x
            let dy = y - center.y
            let length = max(sqrt(dx * dx + dy * dy), 0.001)
            let wobble = radius * 0.26 * amount * Self.noise(index)
            x += dx / length * wobble
            y += dy / length * wobble

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.closeSubpath()
        return path
    }

    private static func noise(_ index: Int) -> CGFloat {
        let value = sin(Double(index) * 127.1) * 43758.5453
        return CGFloat(value - value.rounded(.down)) * 2 - 1
    }

    private static func pointOnRect(_ rect: CGRect, t: Double) -> CGPoint {
        let perimeter = 2 * (rect.width + rect.height)
        var distance = t * perimeter

        if distance < rect.width { return CGPoint(x: rect.minX + distance, y: rect.minY) }
        distance -= rect.width
        if distance < rect.height { return CGPoint(x: rect.maxX, y: rect.minY + distance) }
        distance -= rect.height
        if distance < rect.width { return CGPoint(x: rect.maxX - distance, y: rect.maxY) }
        distance -= rect.width
        return CGPoint(x: rect.minX, y: rect.maxY - distance)
    }
}

/// The page you just wrote, crumpling as it drops toward the bin.
struct CrumplingPage: View {
    /// 0 flat page · 1 balled up and gone.
    let progress: Double
    var width: CGFloat = 104
    var height: CGFloat = 128

    private var amount: Double { min(max(progress, 0), 1) }

    var body: some View {
        CrumpledPaper(crumple: amount)
            .fill(
                LinearGradient(
                    colors: [.white, ClearTheme.creamDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                CrumpledPaper(crumple: amount)
                    .stroke(ClearTheme.forest.opacity(0.18), lineWidth: 1.5)
            }
            .overlay {
                // Written lines, wiped out as the page balls up.
                VStack(alignment: .leading, spacing: height * 0.07) {
                    ForEach(0..<5, id: \.self) { line in
                        Capsule()
                            .fill(ClearTheme.muted.opacity(0.45))
                            .frame(
                                width: width * (line == 4 ? 0.36 : 0.62),
                                height: max(2, height * 0.022)
                            )
                    }
                }
                .opacity(1 - amount * 2.2)
            }
            .overlay {
                // Creases fanning out from the middle.
                ZStack {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule()
                            .fill(ClearTheme.muted.opacity(0.30))
                            .frame(width: max(1, width * 0.012), height: height * 0.42)
                            .rotationEffect(.degrees(Double(index) * 41 - 82))
                    }
                }
                .opacity(amount * 0.9)
            }
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

/// Screws a live view up like paper: the real content keeps rendering inside a
/// crumpling outline, with creases and a squelch as it balls up.
struct CrumpleEffect: ViewModifier {
    let progress: Double
    /// Where the ball ends up — the bin lives at the bottom of the screen.
    var travel: CGFloat = 240

    private var amount: Double { min(max(progress, 0), 1) }

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack {
                    ForEach(0..<6, id: \.self) { index in
                        Capsule()
                            .fill(ClearTheme.forest.opacity(0.12))
                            .frame(width: 2)
                            .rotationEffect(.degrees(Double(index) * 34 - 85))
                    }
                }
                .opacity(amount)
                .allowsHitTesting(false)
            }
            .mask {
                CrumpledPaper(crumple: amount)
                    .foregroundStyle(.black)
            }
            .scaleEffect(1 - 0.55 * amount)
            .scaleEffect(
                x: 1 + 0.07 * sin(amount * 26),
                y: 1 - 0.07 * sin(amount * 26)
            )
            .rotationEffect(.degrees(sin(amount * 17) * 15 * amount))
            .offset(y: travel * CGFloat(pow(amount, 1.5)))
            .opacity(amount > 0.94 ? 0 : 1)
    }
}

extension View {
    func crumpling(progress: Double, travel: CGFloat = 240) -> some View {
        modifier(CrumpleEffect(progress: progress, travel: travel))
    }
}

/// The mascot artwork. Falls back to the drawn bin until the illustration is
/// dropped into `PipBin.imageset`, so the app builds and runs either way.
struct PipArtwork: View {
    var size: CGFloat = 120
    var mood: PipMascot.Mood = .happy
    var chew: Double = 0

    private var hasArtwork: Bool {
        #if os(iOS)
        UIImage(named: "PipBin") != nil
        #else
        NSImage(named: "PipBin") != nil
        #endif
    }

    var body: some View {
        Group {
            if hasArtwork {
                Image("PipBin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                PipMascot(mood: mood, size: size * 0.9, chew: chew)
            }
        }
        .accessibilityLabel("Pip, your DumpIt bin")
    }
}

/// A torn scrap of paper. Edges wander per `seed`, so no two entries in the
/// bin are cut the same way.
struct ScrapPaper: Shape {
    var seed: Int = 0
    /// Edge wander as a fraction of the shorter side.
    var roughness: CGFloat = 0.035

    func path(in rect: CGRect) -> Path {
        let amplitude = min(rect.width, rect.height) * roughness
        let perStep: CGFloat = 22
        var path = Path()

        func jitter(_ index: Int) -> CGFloat {
            let value = sin(Double(index &* 7 &+ seed &* 131) * 12.9898) * 43758.5453
            return CGFloat(value - value.rounded(.down)) * 2 - 1
        }

        var counter = 0
        func edge(from start: CGPoint, to end: CGPoint, normal: CGPoint) {
            let length = max(abs(end.x - start.x), abs(end.y - start.y))
            let steps = max(3, Int(length / perStep))
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                counter += 1
                let wobble = jitter(counter) * amplitude
                path.addLine(to: CGPoint(
                    x: start.x + (end.x - start.x) * t + normal.x * wobble,
                    y: start.y + (end.y - start.y) * t + normal.y * wobble
                ))
            }
        }

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        edge(from: CGPoint(x: rect.minX, y: rect.minY),
             to: CGPoint(x: rect.maxX, y: rect.minY),
             normal: CGPoint(x: 0, y: 1))
        edge(from: CGPoint(x: rect.maxX, y: rect.minY),
             to: CGPoint(x: rect.maxX, y: rect.maxY),
             normal: CGPoint(x: -1, y: 0))
        edge(from: CGPoint(x: rect.maxX, y: rect.maxY),
             to: CGPoint(x: rect.minX, y: rect.maxY),
             normal: CGPoint(x: 0, y: -1))
        edge(from: CGPoint(x: rect.minX, y: rect.maxY),
             to: CGPoint(x: rect.minX, y: rect.minY),
             normal: CGPoint(x: 1, y: 0))
        path.closeSubpath()
        return path
    }
}

/// Paper that has been screwed up and flattened back out: torn edges, fold
/// lines, and a dirty shading across the creases.
struct ScrapPaperSurface: View {
    var seed: Int = 0
    /// More creases and grubbier shading for a page you are re-reading.
    var heavy = false

    private func crease(_ index: Int) -> some View {
        let value = sin(Double(index &* 13 &+ seed &* 71) * 78.233) * 43758.5453
        let random = value - value.rounded(.down)
        return Capsule()
            .fill(ClearTheme.forest.opacity(heavy ? 0.075 : 0.05))
            .frame(width: heavy ? 1.5 : 1)
            .rotationEffect(.degrees(random * 180))
            .offset(
                x: CGFloat(random * 2 - 1) * 70,
                y: CGFloat((random * 3).truncatingRemainder(dividingBy: 1) * 2 - 1) * 60
            )
    }

    var body: some View {
        ScrapPaper(seed: seed)
            .fill(
                LinearGradient(
                    colors: [.white, ClearTheme.creamDeep.opacity(heavy ? 0.9 : 0.65)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                ZStack {
                    ForEach(0..<(heavy ? 9 : 5), id: \.self) { crease($0) }
                }
                .clipShape(ScrapPaper(seed: seed))
                .allowsHitTesting(false)
            }
            .overlay {
                // Grubby shading where the folds bunched up.
                RadialGradient(
                    colors: [.clear, ClearTheme.forest.opacity(heavy ? 0.09 : 0.05)],
                    center: .init(x: 0.35, y: 0.4),
                    startRadius: 20,
                    endRadius: heavy ? 320 : 190
                )
                .clipShape(ScrapPaper(seed: seed))
                .allowsHitTesting(false)
            }
            .overlay {
                ScrapPaper(seed: seed)
                    .stroke(ClearTheme.forest.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: ClearTheme.forest.opacity(0.10), radius: 7, y: 4)
    }
}
