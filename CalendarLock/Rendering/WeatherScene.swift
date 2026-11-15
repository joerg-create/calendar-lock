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

    /// Sky gradient, top to horizon. The top stays dark enough for the white clock.
    var sky: [Color] { palette.sky.map(\.color) }

    /// All colors of one scene, from sky to the front hill.
    struct Palette {
        /// Sky from top to horizon.
        var sky: [Hex]
        /// Landscape layers from back (hazy, close to the horizon color) to front (darkest).
        var hills: [Hex]
        /// Lit top and shaded underside of the clouds.
        var cloudLight: Hex
        var cloudShade: Hex
        /// Thin bright edge on top of the clouds.
        var cloudRim: Hex
        /// Haze lying in the valleys between the layers.
        var mist: Hex
    }

    /// A color written as 0xRRGGBB.
    struct Hex {
        var value: UInt32
        init(_ value: UInt32) { self.value = value }
        var color: Color {
            Color(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
        }
    }

    var palette: Palette {
        switch self {
        case .clear:
            return Palette(sky: [Hex(0x0A2E78), Hex(0x1767B8), Hex(0x29A5C9), Hex(0x7FD3CF), Hex(0xFFC79E)],
                           hills: [Hex(0x6FB5AE), Hex(0x3E8E86), Hex(0x226B63), Hex(0x0F4A44)],
                           cloudLight: Hex(0xFFFFFF), cloudShade: Hex(0xC9DBEA), cloudRim: Hex(0xFFF4E0),
                           mist: Hex(0xFFE3CC))
        case .partlyCloudy:
            return Palette(sky: [Hex(0x0E3C86), Hex(0x2272C9), Hex(0x4FA3E3), Hex(0x9FD2F2), Hex(0xE6F2F7)],
                           hills: [Hex(0x86B9A4), Hex(0x5A9C80), Hex(0x3A7C5E), Hex(0x1E5A40)],
                           cloudLight: Hex(0xFFFFFF), cloudShade: Hex(0x9DB3D3), cloudRim: Hex(0xFFFFFF),
                           mist: Hex(0xE8F4F8))
        case .cloudy:
            return Palette(sky: [Hex(0x26304F), Hex(0x434A70), Hex(0x6E6A8E), Hex(0xB28EA4), Hex(0xE6B9B8)],
                           hills: [Hex(0xA98AA2), Hex(0x86688A), Hex(0x634B6E), Hex(0x3F2F4D)],
                           cloudLight: Hex(0xD9D6E8), cloudShade: Hex(0x5E6185), cloudRim: Hex(0xF4DCE4),
                           mist: Hex(0xE9C3C4))
        case .fog:
            return Palette(sky: [Hex(0x5D5A8C), Hex(0x8C83B3), Hex(0xBBA9CF), Hex(0xEABFB8), Hex(0xF8D9C4)],
                           hills: [Hex(0xC9B4CF), Hex(0xAA97BD), Hex(0x8A7AA6), Hex(0x665A86)],
                           cloudLight: Hex(0xF3E6EE), cloudShade: Hex(0xB5A7C8), cloudRim: Hex(0xFFF0E6),
                           mist: Hex(0xF6E2DA))
        case .rain:
            return Palette(sky: [Hex(0x10163A), Hex(0x1B2A55), Hex(0x1E4366), Hex(0x1F6470), Hex(0x2C7E80)],
                           hills: [Hex(0x2B6670), Hex(0x1C4D5A), Hex(0x133846), Hex(0x0A2431)],
                           cloudLight: Hex(0x56648A), cloudShade: Hex(0x1D2645), cloudRim: Hex(0x8494B8),
                           mist: Hex(0x3C8A8C))
        case .snow:
            return Palette(sky: [Hex(0x162452), Hex(0x2D4787), Hex(0x5B6FB2), Hex(0x9C97CF), Hex(0xCFC4E6)],
                           hills: [Hex(0xA9B0DD), Hex(0x7E88C2), Hex(0x5A64A0), Hex(0xDCE4F6)],
                           cloudLight: Hex(0xE6E8F6), cloudShade: Hex(0x8C93C2), cloudRim: Hex(0xFFFFFF),
                           mist: Hex(0xE1DAF2))
        case .storm:
            return Palette(sky: [Hex(0x12082A), Hex(0x2A0F4A), Hex(0x4C1663), Hex(0x7A2672), Hex(0x9C3D7E)],
                           hills: [Hex(0x5A2A6B), Hex(0x3F1B55), Hex(0x2A0F3F), Hex(0x170726)],
                           cloudLight: Hex(0x4E3470), cloudShade: Hex(0x1C0D33), cloudRim: Hex(0xC08AE6),
                           mist: Hex(0x8E3C82))
        }
    }
}

/// Draws a small landscape under a sky that matches the weather: sun, clouds,
/// rain, snow, fog or lightning.
///
/// Layout rules: the top quarter stays calm for the Lock Screen clock, the
/// agenda area in the middle has nothing busy behind it, and the landscape
/// starts at about 75 % of the height.
struct WeatherSceneView: View {
    let scene: WeatherScene
    var seed: UInt64 = 1

    var body: some View {
        ZStack {
            LinearGradient(stops: skyStops, startPoint: .top, endPoint: .bottom)
            Canvas { context, size in draw(in: &context, size: size) }
        }
    }

    private var palette: WeatherScene.Palette { scene.palette }

    /// The sky colors spread so the horizon color sits where the hills begin.
    private var skyStops: [Gradient.Stop] {
        let colors = scene.sky
        let locations: [CGFloat] = [0, 0.3, 0.52, 0.68, 0.78]
        return zip(colors, locations).map { Gradient.Stop(color: $0, location: $1) }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        var random = SeededRandom(seed: seed &+ 101)
        switch scene {
        case .clear:
            sun(in: &context, size: size, strength: 1, rays: true)
            landscape(in: &context, size: size, random: &random, mountains: false)
        case .partlyCloudy:
            sun(in: &context, size: size, strength: 0.9, rays: false)
            // Below the clock: white clouds behind the white clock make it hard to read.
            clouds(in: &context, size: size, random: &random, count: 5, band: 0.34...0.66, scale: 1, opacity: 0.95)
            landscape(in: &context, size: size, random: &random, mountains: false)
        case .cloudy:
            glow(in: &context, center: CGPoint(x: size.width * 0.72, y: size.height * 0.45), radius: size.width * 0.5,
                 color: WeatherScene.Hex(0xFFD7C2).color, opacity: 0.45)
            clouds(in: &context, size: size, random: &random, count: 6, band: 0.34...0.66, scale: 1.1, opacity: 0.85)
            landscape(in: &context, size: size, random: &random, mountains: true)
        case .fog:
            glow(in: &context, center: CGPoint(x: size.width * 0.3, y: size.height * 0.7), radius: size.width * 0.6,
                 color: WeatherScene.Hex(0xFFE0C2).color, opacity: 0.6)
            landscape(in: &context, size: size, random: &random, mountains: true, mistStrength: 0.85)
            mistBands(in: &context, size: size, random: &random)
        case .rain:
            clouds(in: &context, size: size, random: &random, count: 5, band: 0.0...0.12, scale: 1.3, opacity: 0.45)
            clouds(in: &context, size: size, random: &random, count: 4, band: 0.34...0.55, scale: 1.1, opacity: 0.6)
            landscape(in: &context, size: size, random: &random, mountains: false, lights: true)
            rain(in: &context, size: size, random: &random, count: 190, color: WeatherScene.Hex(0xA9D6E8).color, opacity: 0.4)
        case .snow:
            landscape(in: &context, size: size, random: &random, mountains: true, snowCaps: true)
            snowfall(in: &context, size: size, random: &random)
        case .storm:
            clouds(in: &context, size: size, random: &random, count: 6, band: 0.0...0.14, scale: 1.3, opacity: 0.6)
            clouds(in: &context, size: size, random: &random, count: 4, band: 0.36...0.58, scale: 1.1, opacity: 0.7)
            lightning(in: &context, size: size, random: &random)
            landscape(in: &context, size: size, random: &random, mountains: true)
            rain(in: &context, size: size, random: &random, count: 150, color: WeatherScene.Hex(0xE4D2F2).color, opacity: 0.32)
        }
    }

    // MARK: Sky

    /// Sun in the top right corner, above the clock, with a wide soft glow.
    private func sun(in context: inout GraphicsContext, size: CGSize, strength: Double, rays: Bool) {
        let center = CGPoint(x: size.width * 0.84, y: size.height * 0.08)
        glow(in: &context, center: center, radius: size.width * 0.75, color: WeatherScene.Hex(0xFFD9A0).color, opacity: 0.55 * strength)
        if rays {
            var layer = context
            layer.addFilter(.blur(radius: size.width * 0.012))
            layer.opacity = 0.09 * strength
            let length = size.width * 1.1
            for index in 0..<11 {
                // Rays fan out down and to the left, away from the corner.
                let angle = Double.pi * (0.52 + 0.05 * Double(index)) + (index.isMultiple(of: 2) ? 0 : 0.012)
                let spread = 0.018 + 0.01 * Double(index % 3)
                var ray = Path()
                ray.move(to: center)
                ray.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle - spread)) * length, y: center.y + CGFloat(sin(angle - spread)) * length))
                ray.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle + spread)) * length, y: center.y + CGFloat(sin(angle + spread)) * length))
                ray.closeSubpath()
                layer.fill(ray, with: .linearGradient(
                    Gradient(colors: [WeatherScene.Hex(0xFFF3D6).color, .clear]),
                    startPoint: center, endPoint: CGPoint(x: center.x - length * 0.6, y: center.y + length * 0.6)))
            }
        }
        let radius = size.width * 0.075
        var halo = context
        halo.addFilter(.blur(radius: size.width * 0.03))
        halo.opacity = 0.8 * strength
        halo.fill(circle(center, radius * 1.6), with: .color(WeatherScene.Hex(0xFFE7B8).color))
        var disc = context
        disc.addFilter(.blur(radius: 1.5))
        disc.opacity = strength
        disc.fill(circle(center, radius), with: .radialGradient(
            Gradient(colors: [WeatherScene.Hex(0xFFFDF2).color, WeatherScene.Hex(0xFFE9B5).color]),
            center: center, startRadius: 0, endRadius: radius))
    }

    private func glow(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        var layer = context
        layer.opacity = opacity
        layer.fill(circle(center, radius), with: .radialGradient(
            Gradient(colors: [color, color.opacity(0)]), center: center, startRadius: 0, endRadius: radius))
    }

    /// Fluffy clouds: a lit top, a shaded underside and a thin bright rim.
    private func clouds(in context: inout GraphicsContext, size: CGSize, random: inout SeededRandom,
                        count: Int, band: ClosedRange<CGFloat>, scale: CGFloat, opacity: Double) {
        var layer = context
        layer.opacity = opacity
        for _ in 0..<count {
            let width = size.width * random.range(0.42, 0.72) * scale
            let height = width * random.range(0.3, 0.38)
            let center = CGPoint(x: random.range(-0.05, 1.05) * size.width,
                                 y: random.range(band.lowerBound, band.upperBound) * size.height)
            let shape = cloudShape(center: center, width: width, height: height, random: &random)
            let bounds = shape.boundingRect

            var rim = layer
            rim.addFilter(.blur(radius: size.width * 0.01))
            rim.opacity = 0.8
            rim.translateBy(x: 0, y: -height * 0.06)
            rim.fill(shape, with: .color(palette.cloudRim.color))

            var body = layer
            body.addFilter(.blur(radius: size.width * 0.006))
            body.fill(shape, with: .linearGradient(
                Gradient(stops: [
                    .init(color: palette.cloudLight.color, location: 0),
                    .init(color: palette.cloudLight.color, location: 0.35),
                    .init(color: palette.cloudShade.color, location: 1),
                ]),
                startPoint: CGPoint(x: bounds.midX, y: bounds.minY),
                endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)))
        }
    }

    /// A flat-bottomed cloud built from a base and a few rounded puffs.
    private func cloudShape(center: CGPoint, width: CGFloat, height: CGFloat, random: inout SeededRandom) -> Path {
        var path = Path()
        let baseY = center.y + height * 0.2
        path.addRoundedRect(in: CGRect(x: center.x - width / 2, y: baseY - height * 0.35, width: width, height: height * 0.45),
                            cornerSize: CGSize(width: height * 0.22, height: height * 0.22))
        let puffs = 4
        for index in 0..<puffs {
            let t = (CGFloat(index) + 0.5) / CGFloat(puffs)
            let middle = 1 - abs(t - 0.5) * 2
            let radius = height * (0.32 + 0.38 * middle) * random.range(0.85, 1.1)
            let x = center.x - width / 2 + width * t + random.range(-0.04, 0.04) * width
            path.addEllipse(in: CGRect(x: x - radius, y: baseY - height * 0.1 - radius * 1.5, width: radius * 2, height: radius * 2))
        }
        return path
    }

    // MARK: Landscape

    /// Three to four layers of hills or mountains. Layers further back are lighter
    /// and closer to the horizon color, like distant land seen through air.
    private func landscape(in context: inout GraphicsContext, size: CGSize, random: inout SeededRandom,
                           mountains: Bool, snowCaps: Bool = false, lights: Bool = false, mistStrength: Double = 0.2) {
        let hills = palette.hills
        let tops: [CGFloat] = [0.75, 0.8, 0.86, 0.92]
        let heights: [CGFloat] = mountains ? [0.1, 0.075, 0.055, 0.04] : [0.06, 0.05, 0.04, 0.035]
        for index in hills.indices {
            let jagged = mountains && index < 2
            let ridge = ridgePath(size: size, baseY: size.height * tops[index], height: size.height * heights[index],
                                  peaks: jagged ? 3 + index : 2 + index, jagged: jagged, random: &random)
            var layer = context
            if snowCaps && index == hills.count - 1 {
                // Snowy foreground: bright on top, a cool shade further down.
                let top = size.height * (tops[index] - heights[index])
                layer.fill(ridge, with: .linearGradient(
                    Gradient(colors: [hills[index].color, WeatherScene.Hex(0xA9B4DE).color]),
                    startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: size.height)))
            } else {
                layer.fill(ridge, with: .color(hills[index].color))
            }

            if snowCaps && index < 3 {
                // White caps on the peaks, fading out further down the slope.
                var caps = layer
                caps.clip(to: ridge)
                let peakTop = size.height * (tops[index] - heights[index])
                let snowline = size.height * (tops[index] - heights[index] * 0.45)
                let fadeEnd = snowline + size.height * 0.015
                caps.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: fadeEnd)),
                          with: .linearGradient(Gradient(stops: [
                              .init(color: .white.opacity(0.95), location: 0),
                              .init(color: .white.opacity(0.9), location: 0.7),
                              .init(color: .white.opacity(0), location: 1),
                          ]), startPoint: CGPoint(x: 0, y: peakTop), endPoint: CGPoint(x: 0, y: fadeEnd)))
            }
            if lights && index == 2 {
                townLights(in: &layer, size: size, baseY: size.height * tops[index], random: &random)
            }
            if index < hills.count - 1 {
                // Haze at the foot of the layer, so the next one stands out against it.
                let footY = size.height * (tops[index] + 0.02)
                var mist = context
                mist.opacity = mistStrength
                mist.addFilter(.blur(radius: size.height * 0.01))
                mist.fill(Path(CGRect(x: -20, y: footY - size.height * 0.05, width: size.width + 40, height: size.height * 0.09)),
                          with: .linearGradient(Gradient(colors: [palette.mist.color.opacity(0), palette.mist.color, palette.mist.color.opacity(0)]),
                                                startPoint: CGPoint(x: 0, y: footY - size.height * 0.05),
                                                endPoint: CGPoint(x: 0, y: footY + size.height * 0.04)))
            }
        }
    }

    /// The outline of one layer, filled down to the bottom edge.
    private func ridgePath(size: CGSize, baseY: CGFloat, height: CGFloat, peaks: Int, jagged: Bool,
                           random: inout SeededRandom) -> Path {
        var points: [CGPoint] = []
        let segments = peaks * 2
        for step in 0...segments {
            let x = size.width * (CGFloat(step) / CGFloat(segments)) + random.range(-0.06, 0.06) * size.width
            let isPeak = step % 2 == 1
            let lift = isPeak ? random.range(0.45, 1) : random.range(0, 0.35)
            points.append(CGPoint(x: x, y: baseY - height * lift))
        }
        var path = Path()
        path.move(to: CGPoint(x: -10, y: size.height + 10))
        path.addLine(to: CGPoint(x: -10, y: points[0].y))
        if jagged {
            // Mountains: straight flanks with a small kink on each slope.
            for (index, point) in points.enumerated() where index > 0 {
                let previous = points[index - 1]
                let kink = CGPoint(x: (previous.x + point.x) / 2 + random.range(-6, 6),
                                   y: (previous.y + point.y) / 2 + random.range(-height * 0.12, height * 0.12))
                path.addLine(to: kink)
                path.addLine(to: point)
            }
        } else {
            // Hills: smooth curves through the midpoints.
            for index in 1..<points.count {
                let previous = points[index - 1]
                let middle = CGPoint(x: (previous.x + points[index].x) / 2, y: (previous.y + points[index].y) / 2)
                path.addQuadCurve(to: middle, control: previous)
            }
            path.addLine(to: points[points.count - 1])
        }
        path.addLine(to: CGPoint(x: size.width + 10, y: points[points.count - 1].y))
        path.addLine(to: CGPoint(x: size.width + 10, y: size.height + 10))
        path.closeSubpath()
        return path
    }

    /// A few warm, blurred lights of a distant village, mirrored faintly below.
    private func townLights(in context: inout GraphicsContext, size: CGSize, baseY: CGFloat, random: inout SeededRandom) {
        var layer = context
        layer.addFilter(.blur(radius: 1.2))
        for _ in 0..<14 {
            let point = CGPoint(x: random.range(0.08, 0.92) * size.width, y: baseY + random.range(0.005, 0.03) * size.height)
            let radius = random.range(1, 2.2)
            layer.opacity = Double(random.range(0.5, 0.9))
            layer.fill(circle(point, radius), with: .color(WeatherScene.Hex(0xFFD58A).color))
            var reflection = context
            reflection.addFilter(.blur(radius: 2))
            reflection.opacity = 0.25
            reflection.fill(Path(CGRect(x: point.x - radius * 0.6, y: point.y + 3, width: radius * 1.2, height: size.height * 0.02)),
                            with: .color(WeatherScene.Hex(0xFFD58A).color))
        }
    }

    /// Soft horizontal veils of fog over the mountains.
    private func mistBands(in context: inout GraphicsContext, size: CGSize, random: inout SeededRandom) {
        var layer = context
        layer.addFilter(.blur(radius: size.height * 0.02))
        for index in 0..<4 {
            let y = size.height * (0.66 + 0.07 * CGFloat(index)) + random.range(-8, 8)
            layer.opacity = Double(random.range(0.35, 0.55))
            layer.fill(Path(ellipseIn: CGRect(x: -size.width * 0.3 + random.range(-40, 40), y: y,
                                              width: size.width * 1.6, height: size.height * 0.04)),
                       with: .color(palette.mist.color))
        }
    }

    // MARK: Weather

    private func rain(in context: inout GraphicsContext, size: CGSize, random: inout SeededRandom,
                      count: Int, color: Color, opacity: Double) {
        var layer = context
        layer.opacity = opacity
        let length = size.height * 0.035
        let slant = length * 0.28
        for _ in 0..<count {
            let x = random.range(-20, size.width + 20)
            let y = random.range(size.height * 0.08, size.height)
            let l = length * random.range(0.6, 1.3)
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - slant, y: y + l))
            layer.stroke(path, with: .linearGradient(Gradient(colors: [color.opacity(0), color]),
                                                      startPoint: CGPoint(x: x, y: y), endPoint: CGPoint(x: x - slant, y: y + l)),
                         style: StrokeStyle(lineWidth: random.range(0.8, 1.5), lineCap: .round))
        }
    }

    /// Small sharp flakes plus a few large, out-of-focus ones near the edges.
    private func snowfall(in context: inout GraphicsContext, size: CGSize, random: inout SeededRandom) {
        for _ in 0..<170 {
            let point = CGPoint(x: random.range(0, size.width), y: random.range(0, size.height))
            let radius = random.range(0.9, 2.6)
            var flake = context
            flake.opacity = Double(random.range(0.45, 0.9))
            flake.fill(circle(point, radius), with: .color(.white))
        }
        var bokeh = context
        bokeh.addFilter(.blur(radius: size.width * 0.012))
        for _ in 0..<9 {
            // Large flakes stay at the left and right edges, away from the text.
            let x = random.unit() < 0.5 ? random.range(-0.04, 0.12) : random.range(0.88, 1.04)
            let point = CGPoint(x: x * size.width, y: random.range(0.1, 0.95) * size.height)
            bokeh.opacity = Double(random.range(0.2, 0.4))
            bokeh.fill(circle(point, size.width * random.range(0.02, 0.04)), with: .color(.white))
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
        glow(in: &context, center: CGPoint(x: size.width * 0.86, y: size.height * 0.12), radius: size.width * 0.45,
             color: WeatherScene.Hex(0xD9A6FF).color, opacity: 0.45)
        var outer = context
        outer.addFilter(.blur(radius: 10))
        outer.stroke(path, with: .color(WeatherScene.Hex(0xD7B8FF).color), lineWidth: 9)
        context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
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
