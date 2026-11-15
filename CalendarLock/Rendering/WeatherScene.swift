import SwiftUI

/// The kind of sky drawn by the "Wetter" background, from a WMO weather code.
enum WeatherScene: String, CaseIterable {
    case clear, partlyCloudy, cloudy, fog, rain, snow, storm

    init(code: Int) {
        switch code {
        case 0, 1: self = .clear
        case 2: self = .partlyCloudy
        case 3: self = .cloudy
        case 45, 48: self = .fog
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: self = .rain
        case 71, 73, 75, 77, 85, 86: self = .snow
        case 95, 96, 99: self = .storm
        default: self = .cloudy
        }
    }

    /// Sky gradient from the zenith to the hazy horizon.
    var sky: [Color] { palette.sky.map(\.color) }

    /// All colors of one scene.
    struct Palette {
        /// Sky from the zenith (deepest) to the horizon (palest).
        var sky: [Hex]
        /// Color of the nearest ground. Layers further away are mixed towards `haze`.
        var land: Hex
        /// Color of the air between the viewer and distant land.
        var haze: Hex
        /// Sunlit and shaded parts of the clouds.
        var cloudLight: Hex
        var cloudShade: Hex
    }

    /// A color written as 0xRRGGBB.
    struct Hex {
        var red: Double
        var green: Double
        var blue: Double

        init(_ value: UInt32) {
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        }

        private init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        var color: Color { Color(.sRGB, red: red, green: green, blue: blue) }

        /// Linear mix: 0 keeps this color, 1 gives `other`.
        func mixed(with other: Hex, _ amount: Double) -> Hex {
            Hex(red: red + (other.red - red) * amount,
                green: green + (other.green - green) * amount,
                blue: blue + (other.blue - blue) * amount)
        }
    }

    var palette: Palette {
        switch self {
        case .clear:
            return Palette(sky: [Hex(0x2C6FD1), Hex(0x4A8FDC), Hex(0x7DB3E6), Hex(0xB7D6EE), Hex(0xE9EEEA)],
                           land: Hex(0x3F7448), haze: Hex(0xB5CFE4),
                           cloudLight: Hex(0xFFFFFF), cloudShade: Hex(0xC3CFDD))
        case .partlyCloudy:
            return Palette(sky: [Hex(0x3474CF), Hex(0x5592DB), Hex(0x86B5E5), Hex(0xBCD7EE), Hex(0xE6EDF1)],
                           land: Hex(0x46794B), haze: Hex(0xBDD4E8),
                           cloudLight: Hex(0xFFFFFF), cloudShade: Hex(0xC2CDDB))
        case .cloudy:
            return Palette(sky: [Hex(0x8494AA), Hex(0x9DAABB), Hex(0xB7C0CC), Hex(0xCDD2D9), Hex(0xDFE1E4)],
                           land: Hex(0x56645E), haze: Hex(0xC6CCD4),
                           cloudLight: Hex(0xF1F3F6), cloudShade: Hex(0xA4ADBB))
        case .fog:
            return Palette(sky: [Hex(0xA4A6B6), Hex(0xBAB9C6), Hex(0xCFCCD4), Hex(0xE2DCDC), Hex(0xEDE6E1)],
                           land: Hex(0x6F746D), haze: Hex(0xE2DEDD),
                           cloudLight: Hex(0xF3F1F2), cloudShade: Hex(0xC9C7CF))
        case .rain:
            return Palette(sky: [Hex(0x4E6D8B), Hex(0x607E99), Hex(0x7690A6), Hex(0x90A4B4), Hex(0xA8B7C1)],
                           land: Hex(0x35524D), haze: Hex(0x8EA2AF),
                           cloudLight: Hex(0xA9B4C2), cloudShade: Hex(0x56626F))
        case .snow:
            return Palette(sky: [Hex(0x6A91C6), Hex(0x8BABD5), Hex(0xB0C7E2), Hex(0xD3E0EE), Hex(0xEBF0F6)],
                           land: Hex(0xE6ECF5), haze: Hex(0xCFDBEA),
                           cloudLight: Hex(0xF7F9FC), cloudShade: Hex(0xB6C3D6))
        case .storm:
            return Palette(sky: [Hex(0x2A2545), Hex(0x3B315D), Hex(0x534473), Hex(0x725F89), Hex(0x957C9A)],
                           land: Hex(0x272536), haze: Hex(0x6A5F80),
                           cloudLight: Hex(0x6B6588), cloudShade: Hex(0x26223B))
        }
    }

    /// Strength of the soft dark veil at the top that keeps the white clock
    /// readable on bright skies.
    var topScrim: Double {
        switch self {
        case .storm: 0.12
        case .clear, .partlyCloudy, .rain: 0.22
        case .cloudy, .fog, .snow: 0.3
        }
    }

    /// How rugged the landscape is: 0 gives rolling hills, 1 sharp mountains.
    fileprivate var roughness: CGFloat {
        switch self {
        case .clear, .partlyCloudy: 0.35
        case .cloudy, .rain: 0.5
        case .fog, .storm: 0.65
        case .snow: 0.9
        }
    }

    /// How strongly mist lies in the valleys between the ridges.
    fileprivate var valleyMist: Double {
        switch self {
        case .fog: 0.85
        case .rain, .cloudy: 0.4
        case .snow, .storm: 0.3
        case .clear, .partlyCloudy: 0.25
        }
    }
}

/// Draws a landscape under a sky that matches the weather, in a soft,
/// photographic style: sun glare, volumetric clouds, rain, snow, fog or lightning.
///
/// Layout rules: the top quarter stays calm for the Lock Screen clock, the
/// agenda area in the middle has nothing busy behind it, and the landscape
/// starts at about 74 % of the height.
struct WeatherSceneView: View {
    let scene: WeatherScene
    var seed: UInt64 = 1

    var body: some View {
        ZStack {
            LinearGradient(stops: skyStops, startPoint: .top, endPoint: .bottom)
            Canvas { context, size in draw(in: &context, size: size) }
            // Bright skies get a soft dark veil behind the clock, fading out above the agenda.
            LinearGradient(stops: [
                .init(color: .black.opacity(scene.topScrim), location: 0),
                .init(color: .black.opacity(scene.topScrim * 0.6), location: 0.18),
                .init(color: .black.opacity(0), location: 0.34),
            ], startPoint: .top, endPoint: .bottom)
        }
    }

    private var palette: WeatherScene.Palette { scene.palette }

    /// Deep at the zenith, with most of the change near the horizon, like a real sky.
    private var skyStops: [Gradient.Stop] {
        let locations: [CGFloat] = [0, 0.28, 0.5, 0.66, 0.76]
        return zip(scene.sky, locations).map { Gradient.Stop(color: $0, location: $1) }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        var random = SeededRandom(seed: seed &+ 101)
        horizonGlow(in: &context, size: size)
        switch scene {
        case .clear:
            sun(in: &context, size: size, strength: 1)
            clouds(in: &context, size: size, random: &random, count: 2, band: 0.6...0.68, scale: 0.6, opacity: 0.5)
        case .partlyCloudy:
            sun(in: &context, size: size, strength: 0.85)
            // Below the clock: white clouds behind the white clock make it hard to read.
            clouds(in: &context, size: size, random: &random, count: 5, band: 0.36...0.68, scale: 1, opacity: 1)
        case .cloudy:
            glow(in: &context, center: CGPoint(x: size.width * 0.7, y: size.height * 0.42), radius: size.width * 0.6,
                 color: WeatherScene.Hex(0xFFF3E4).color, opacity: 0.5)
            clouds(in: &context, size: size, random: &random, count: 4, band: 0.02...0.12, scale: 1.4, opacity: 0.55)
            clouds(in: &context, size: size, random: &random, count: 6, band: 0.34...0.7, scale: 1.2, opacity: 0.95)
        case .fog:
            glow(in: &context, center: CGPoint(x: size.width * 0.32, y: size.height * 0.62), radius: size.width * 0.7,
                 color: WeatherScene.Hex(0xFFEFE0).color, opacity: 0.6)
        case .rain:
            clouds(in: &context, size: size, random: &random, count: 5, band: 0.0...0.12, scale: 1.5, opacity: 0.6)
            clouds(in: &context, size: size, random: &random, count: 5, band: 0.34...0.62, scale: 1.2, opacity: 0.75)
        case .snow:
            clouds(in: &context, size: size, random: &random, count: 3, band: 0.36...0.6, scale: 1.1, opacity: 0.6)
        case .storm:
            clouds(in: &context, size: size, random: &random, count: 6, band: 0.0...0.14, scale: 1.5, opacity: 0.8)
            lightning(in: &context, size: size, random: &random)
            clouds(in: &context, size: size, random: &random, count: 5, band: 0.36...0.6, scale: 1.2, opacity: 0.8)
        }
        landscape(in: &context, size: size, random: &random)
        switch scene {
        case .fog:
            fogVeils(in: &context, size: size, random: &random)
        case .rain:
            rain(in: &context, size: size, random: &random, color: WeatherScene.Hex(0xE8F1F6).color)
        case .storm:
            rain(in: &context, size: size, random: &random, color: WeatherScene.Hex(0xD9D2E6).color)
        case .snow:
            snowfall(in: &context, size: size, random: &random)
        default:
            break
        }
    }

    // MARK: Sky

    /// A pale band of light just above the horizon, as in real skies.
    private func horizonGlow(in context: inout GraphicsContext, size: CGSize) {
        var layer = context
        layer.addFilter(.blur(radius: size.height * 0.04))
        layer.opacity = 0.55
        let rect = CGRect(x: -size.width * 0.2, y: size.height * 0.64, width: size.width * 1.4, height: size.height * 0.16)
        layer.fill(Path(ellipseIn: rect), with: .color(palette.sky[palette.sky.count - 1].color))
    }

    /// Sun in the top right corner, above the clock: a wide bloom, a soft halo,
    /// a bright core and two faint lens reflections.
    private func sun(in context: inout GraphicsContext, size: CGSize, strength: Double) {
        let center = CGPoint(x: size.width * 0.84, y: size.height * 0.075)
        glow(in: &context, center: center, radius: size.width * 1.0, color: WeatherScene.Hex(0xFFE4B8).color, opacity: 0.55 * strength)
        glow(in: &context, center: center, radius: size.width * 0.4, color: WeatherScene.Hex(0xFFEBC8).color, opacity: 0.85 * strength)
        glow(in: &context, center: center, radius: size.width * 0.11, color: .white, opacity: 0.95 * strength)
        var core = context
        core.addFilter(.blur(radius: 2))
        core.opacity = strength
        core.fill(circle(center, size.width * 0.04), with: .color(.white))

        // Lens reflections along the line from the sun through the middle of the picture.
        let middle = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        for (t, radius, opacity) in [(0.55, 0.035, 0.07), (0.8, 0.06, 0.05)] as [(CGFloat, CGFloat, Double)] {
            let point = CGPoint(x: center.x + (middle.x - center.x) * t, y: center.y + (middle.y - center.y) * t)
            glow(in: &context, center: point, radius: size.width * radius, color: WeatherScene.Hex(0xFFF0D0).color, opacity: opacity * strength)
        }
    }

    private func glow(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        var layer = context
        layer.opacity = opacity
        layer.fill(circle(center, radius), with: .radialGradient(
            Gradient(stops: [
                .init(color: color, location: 0),
                .init(color: color.opacity(0.35), location: 0.4),
                .init(color: color.opacity(0), location: 1),
            ]), center: center, startRadius: 0, endRadius: radius))
    }

    // MARK: Clouds

    private func clouds(in context: inout GraphicsContext, size: CGSize, random: inout SeededRandom,
                        count: Int, band: ClosedRange<CGFloat>, scale: CGFloat, opacity: Double) {
        var layer = context
        layer.opacity = opacity
        for _ in 0..<count {
            let width = size.width * random.range(0.45, 0.75) * scale
            let height = width * random.range(0.3, 0.42)
            let base = CGPoint(x: random.range(-0.05, 1.05) * size.width,
                               y: random.range(band.lowerBound, band.upperBound) * size.height)
            cloud(in: &layer, base: base, width: width, height: height, random: &random)
        }
    }

    /// One soft cumulus cloud: many small, blurred puffs in a dome, lit from
    /// above and shaded towards the flat base.
    private func cloud(in context: inout GraphicsContext, base: CGPoint, width: CGFloat, height: CGFloat,
                       random: inout SeededRandom) {
        struct Puff { var center: CGPoint; var radius: CGFloat; var light: Double }
        var puffs: [Puff] = []
        for _ in 0..<40 {
            let u = random.range(-1, 1)
            let domeTop = height * (1 - u * u * 0.85)
            let lift = random.range(0, 1) * random.range(0.5, 1) * domeTop
            let radius = height * random.range(0.2, 0.36) * (0.65 + 0.35 * (1 - abs(u)))
            let center = CGPoint(x: base.x + u * width * 0.5, y: base.y - lift)
            puffs.append(Puff(center: center, radius: radius, light: Double(lift / max(domeTop, 1))))
        }
        // Lower, shaded puffs first, so the lit tops lie on top of them.
        puffs.sort { $0.center.y > $1.center.y }

        var layer = context
        layer.addFilter(.blur(radius: height * 0.11))
        for puff in puffs {
            let tone = palette.cloudShade.mixed(with: palette.cloudLight, 0.45 + 0.55 * puff.light)
            let highlight = tone.mixed(with: palette.cloudLight, 0.6)
            let lightPoint = CGPoint(x: puff.center.x - puff.radius * 0.3, y: puff.center.y - puff.radius * 0.45)
            layer.fill(circle(puff.center, puff.radius), with: .radialGradient(
                Gradient(colors: [highlight.color, tone.color]),
                center: lightPoint, startRadius: 0, endRadius: puff.radius * 1.4))
        }
        // A soft shadow along the flat underside.
        var shadow = context
        shadow.addFilter(.blur(radius: height * 0.12))
        shadow.opacity = 0.35
        shadow.fill(Path(ellipseIn: CGRect(x: base.x - width * 0.45, y: base.y - height * 0.12, width: width * 0.9, height: height * 0.22)),
                    with: .color(palette.cloudShade.color))
    }

    // MARK: Landscape

    /// Four ridges from far to near. Distant ones are mixed towards the haze
    /// color and slightly blurred, as seen through air.
    private func landscape(in context: inout GraphicsContext, size: CGSize, random: inout SeededRandom) {
        let tops: [CGFloat] = [0.75, 0.8, 0.86, 0.92]
        let heights: [CGFloat] = [0.1, 0.075, 0.055, 0.045]
        let distance: [Double] = [0.72, 0.5, 0.28, 0.06]
        for index in tops.indices {
            let roughness = index == 0 ? max(scene.roughness, 0.6) : scene.roughness * (1 - CGFloat(index) * 0.2)
            let baseY = size.height * tops[index]
            let height = size.height * heights[index]
            let ridge = ridgePath(size: size, baseY: baseY, height: height, roughness: roughness, random: &random)
            let color = palette.land.mixed(with: palette.haze, distance[index])

            if index > 0 {
                // Mist lying in the valley behind this ridge.
                var mist = context
                mist.opacity = scene.valleyMist
                mist.addFilter(.blur(radius: size.height * 0.012))
                mist.fill(Path(CGRect(x: -20, y: baseY - height * 1.6, width: size.width + 40, height: height * 1.8)),
                          with: .linearGradient(Gradient(colors: [palette.haze.color.opacity(0), palette.haze.color, palette.haze.color.opacity(0)]),
                                                startPoint: CGPoint(x: 0, y: baseY - height * 1.6),
                                                endPoint: CGPoint(x: 0, y: baseY + height * 0.2)))
            }

            var layer = context
            if distance[index] > 0.4 { layer.addFilter(.blur(radius: 1.2)) }
            // Lighter along the crest, darker towards the foot.
            layer.fill(ridge, with: .linearGradient(
                Gradient(colors: [color.mixed(with: palette.haze, 0.18).color, color.mixed(with: WeatherScene.Hex(0x000000), 0.12).color]),
                startPoint: CGPoint(x: 0, y: baseY - height), endPoint: CGPoint(x: 0, y: baseY + height * 1.5)))

            if scene == .snow && index < 3 {
                // Snow on the upper slopes, fading out below the snowline.
                var caps = layer
                caps.clip(to: ridge)
                let peakTop = baseY - height
                let fadeEnd = baseY - height * 0.35
                caps.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: fadeEnd)),
                          with: .linearGradient(Gradient(stops: [
                              .init(color: .white.opacity(0.95), location: 0),
                              .init(color: .white.opacity(0.85), location: 0.6),
                              .init(color: .white.opacity(0), location: 1),
                          ]), startPoint: CGPoint(x: 0, y: peakTop), endPoint: CGPoint(x: 0, y: fadeEnd)))
            }
        }
    }

    /// A natural ridge line from a few layered waves: broad hills, sharper
    /// crests where the land is rugged, and fine detail.
    private func ridgePath(size: CGSize, baseY: CGFloat, height: CGFloat, roughness: CGFloat,
                           random: inout SeededRandom) -> Path {
        let f1 = random.range(1.0, 1.8), p1 = random.range(0, 6.3)
        let f2 = random.range(2.5, 4), p2 = random.range(0, 6.3)
        let f3 = random.range(6, 9), p3 = random.range(0, 6.3)
        let f4 = random.range(14, 20), p4 = random.range(0, 6.3)
        var path = Path()
        path.move(to: CGPoint(x: -10, y: size.height + 10))
        var x: CGFloat = -10
        while x <= size.width + 10 {
            let t = x / size.width * 2 * .pi
            let broad = 0.5 + 0.5 * sin(t * f1 + p1)
            let crest = 1 - abs(sin(t * f2 * 0.5 + p2))
            let rolling = 0.5 + 0.5 * sin(t * f2 + p2)
            let detail = 0.5 + 0.5 * sin(t * f3 + p3)
            let fine = 0.5 + 0.5 * sin(t * f4 + p4)
            let value = broad * 0.5
                + (crest * roughness + rolling * (1 - roughness)) * 0.32
                + detail * 0.12 * (0.4 + roughness)
                + fine * 0.05 * roughness
            path.addLine(to: CGPoint(x: x, y: baseY - height * value))
            x += 3
        }
        path.addLine(to: CGPoint(x: size.width + 10, y: size.height + 10))
        path.closeSubpath()
        return path
    }

    /// Soft layers of fog over the ridges.
    private func fogVeils(in context: inout GraphicsContext, size: CGSize, random: inout SeededRandom) {
        var layer = context
        layer.addFilter(.blur(radius: size.height * 0.025))
        for index in 0..<5 {
            let y = size.height * (0.66 + 0.065 * CGFloat(index)) + random.range(-8, 8)
            layer.opacity = Double(random.range(0.3, 0.5))
            layer.fill(Path(ellipseIn: CGRect(x: -size.width * 0.4 + random.range(-40, 40), y: y,
                                              width: size.width * 1.8, height: size.height * 0.05)),
                       with: .color(palette.haze.color))
        }
    }

    // MARK: Weather

    /// Thin streaks in two depths: many faint, short ones far away and fewer,
    /// longer, slightly blurred ones close by.
    private func rain(in context: inout GraphicsContext, size: CGSize, random: inout SeededRandom, color: Color) {
        let slant: CGFloat = 0.22
        for depth in 0..<2 {
            var layer = context
            layer.addFilter(.blur(radius: depth == 0 ? 0.4 : 1.1))
            let count = depth == 0 ? 220 : 70
            let length = size.height * (depth == 0 ? 0.022 : 0.05)
            for _ in 0..<count {
                let x = random.range(-20, size.width + 20)
                let y = random.range(size.height * 0.06, size.height)
                let l = length * random.range(0.6, 1.3)
                layer.opacity = Double(random.range(depth == 0 ? 0.12 : 0.18, depth == 0 ? 0.35 : 0.45))
                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x - l * slant, y: y + l))
                layer.stroke(path, with: .linearGradient(Gradient(colors: [color.opacity(0), color]),
                                                          startPoint: CGPoint(x: x, y: y), endPoint: CGPoint(x: x - l * slant, y: y + l)),
                             style: StrokeStyle(lineWidth: depth == 0 ? random.range(0.4, 0.8) : random.range(0.8, 1.3), lineCap: .round))
            }
        }
    }

    /// Flakes in three depths: tiny sharp ones far away, medium ones, and a
    /// few large out-of-focus ones near the edges.
    private func snowfall(in context: inout GraphicsContext, size: CGSize, random: inout SeededRandom) {
        let depths: [(count: Int, radius: ClosedRange<CGFloat>, blur: CGFloat, opacity: ClosedRange<CGFloat>)] = [
            (160, 0.5...1.1, 0, 0.45...0.8),
            (60, 1.4...2.4, 0.8, 0.55...0.9),
        ]
        for depth in depths {
            var layer = context
            if depth.blur > 0 { layer.addFilter(.blur(radius: depth.blur)) }
            for _ in 0..<depth.count {
                let point = CGPoint(x: random.range(0, size.width), y: random.range(0, size.height))
                layer.opacity = Double(random.range(depth.opacity.lowerBound, depth.opacity.upperBound))
                layer.fill(circle(point, random.range(depth.radius.lowerBound, depth.radius.upperBound)), with: .color(.white))
            }
        }
        var near = context
        near.addFilter(.blur(radius: size.width * 0.01))
        for _ in 0..<10 {
            // Large flakes stay at the left and right edges, away from the text.
            let x = random.unit() < 0.5 ? random.range(-0.04, 0.11) : random.range(0.89, 1.04)
            let point = CGPoint(x: x * size.width, y: random.range(0.1, 0.95) * size.height)
            near.opacity = Double(random.range(0.25, 0.5))
            near.fill(circle(point, size.width * random.range(0.012, 0.028)), with: .color(.white))
        }
    }

    /// A bolt at the right edge, kept above the weather row and beside the clock,
    /// so it never runs through the agenda.
    private func lightning(in context: inout GraphicsContext, size: CGSize, random: inout SeededRandom) {
        var point = CGPoint(x: size.width * random.range(0.84, 0.9), y: size.height * 0.04)
        var path = Path()
        path.move(to: point)
        while point.y < size.height * 0.25 {
            point = CGPoint(x: point.x + size.width * random.range(-0.05, 0.035),
                            y: point.y + size.height * random.range(0.025, 0.045))
            path.addLine(to: point)
        }
        glow(in: &context, center: CGPoint(x: size.width * 0.86, y: size.height * 0.12), radius: size.width * 0.5,
             color: WeatherScene.Hex(0xDCCBFF).color, opacity: 0.5)
        var outer = context
        outer.addFilter(.blur(radius: 9))
        outer.stroke(path, with: .color(WeatherScene.Hex(0xD8CCFF).color), lineWidth: 8)
        context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    private func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack {
            ForEach(WeatherScene.allCases, id: \.self) { scene in
                WeatherSceneView(scene: scene)
                    .frame(width: 150, height: 325)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding()
    }
}
