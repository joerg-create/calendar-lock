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

    /// Sky gradient, top to bottom. All scenes are dark enough for white text.
    var sky: [Color] {
        func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(.sRGB, red: r, green: g, blue: b) }
        switch self {
        case .clear: return [c(0.05, 0.27, 0.62), c(0.18, 0.52, 0.85), c(0.93, 0.62, 0.38)]
        case .partlyCloudy: return [c(0.08, 0.27, 0.55), c(0.30, 0.52, 0.76), c(0.62, 0.70, 0.80)]
        case .cloudy: return [c(0.20, 0.24, 0.30), c(0.36, 0.40, 0.47), c(0.48, 0.51, 0.56)]
        case .fog: return [c(0.32, 0.35, 0.38), c(0.47, 0.49, 0.51), c(0.56, 0.57, 0.58)]
        case .rain: return [c(0.09, 0.13, 0.20), c(0.18, 0.25, 0.34), c(0.27, 0.34, 0.42)]
        case .snow: return [c(0.18, 0.26, 0.40), c(0.38, 0.47, 0.60), c(0.62, 0.68, 0.76)]
        case .storm: return [c(0.05, 0.05, 0.10), c(0.15, 0.13, 0.22), c(0.25, 0.22, 0.32)]
        }
    }
}

/// Draws a sky for the given weather: sun, clouds, rain, snow, fog or lightning.
struct WeatherSceneView: View {
    let scene: WeatherScene
    var seed: UInt64 = 1

    var body: some View {
        ZStack {
            LinearGradient(colors: scene.sky, startPoint: .top, endPoint: .bottom)
            Canvas { context, size in draw(in: &context, size: size) }
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        var random = SeededRandom(seed: seed &+ 101)
        switch scene {
        case .clear:
            // Top right, above the Lock Screen clock, so the clock stays readable.
            sun(in: &context, size: size, at: CGPoint(x: size.width * 0.84, y: size.height * 0.08), strength: 1)
            haze(in: &context, size: size, color: Color(red: 1, green: 0.75, blue: 0.5), y: 0.95, opacity: 0.35)
        case .partlyCloudy:
            sun(in: &context, size: size, at: CGPoint(x: size.width * 0.84, y: size.height * 0.08), strength: 0.8)
            // Clouds below the clock area: white clouds behind the white clock make it hard to read.
            clouds(in: &context, size: size, random: &random, count: 6, color: .white, opacity: 0.6, band: 0.32...0.9)
        case .cloudy:
            clouds(in: &context, size: size, random: &random, count: 9, color: Color(white: 0.82), opacity: 0.55, band: 0.0...0.75)
            clouds(in: &context, size: size, random: &random, count: 6, color: Color(white: 0.95), opacity: 0.35, band: 0.1...0.9)
        case .fog:
            for index in 0..<7 {
                let y = size.height * (0.15 + 0.13 * CGFloat(index)) + random.range(-20, 20)
                var band = context
                band.addFilter(.blur(radius: size.height * 0.03))
                band.opacity = Double(random.range(0.25, 0.45))
                band.fill(Path(CGRect(x: -40, y: y, width: size.width + 80, height: size.height * 0.05)), with: .color(.white))
            }
        case .rain:
            clouds(in: &context, size: size, random: &random, count: 8, color: Color(white: 0.55), opacity: 0.6, band: 0.0...0.35)
            streaks(in: &context, size: size, random: &random, count: 170, length: size.height * 0.035, color: Color(red: 0.75, green: 0.85, blue: 1), opacity: 0.45)
        case .snow:
            clouds(in: &context, size: size, random: &random, count: 7, color: Color(white: 0.92), opacity: 0.45, band: 0.0...0.3)
            for _ in 0..<160 {
                let point = CGPoint(x: random.range(0, size.width), y: random.range(0, size.height))
                let radius = random.range(1.2, 3.6)
                var flake = context
                flake.opacity = Double(random.range(0.5, 0.95))
                if radius > 2.8 { flake.addFilter(.blur(radius: 1.2)) }
                flake.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(.white))
            }
            haze(in: &context, size: size, color: .white, y: 1.0, opacity: 0.35)
        case .storm:
            clouds(in: &context, size: size, random: &random, count: 9, color: Color(white: 0.35), opacity: 0.7, band: 0.0...0.4)
            lightning(in: &context, size: size, random: &random)
            streaks(in: &context, size: size, random: &random, count: 130, length: size.height * 0.04, color: Color(white: 0.85), opacity: 0.35)
        }
    }

    // MARK: Elements

    private func sun(in context: inout GraphicsContext, size: CGSize, at center: CGPoint, strength: Double) {
        var glow = context
        glow.addFilter(.blur(radius: size.width * 0.18))
        glow.opacity = 0.75 * strength
        let glowRadius = size.width * 0.42
        glow.fill(Path(ellipseIn: CGRect(x: center.x - glowRadius, y: center.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)),
                  with: .color(Color(red: 1, green: 0.85, blue: 0.55)))
        var disc = context
        disc.addFilter(.blur(radius: 4))
        disc.opacity = strength
        let radius = size.width * 0.09
        disc.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                  with: .color(Color(red: 1, green: 0.96, blue: 0.82)))
    }

    /// Soft clouds built from overlapping blurred circles.
    private func clouds(in context: inout GraphicsContext, size: CGSize, random: inout SeededRandom,
                        count: Int, color: Color, opacity: Double, band: ClosedRange<CGFloat>) {
        var layer = context
        layer.addFilter(.blur(radius: size.width * 0.035))
        layer.opacity = opacity
        for _ in 0..<count {
            let center = CGPoint(x: random.range(-0.1, 1.1) * size.width,
                                 y: random.range(band.lowerBound, band.upperBound) * size.height)
            let width = size.width * random.range(0.35, 0.7)
            let height = width * random.range(0.28, 0.4)
            var path = Path()
            path.addEllipse(in: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height))
            for _ in 0..<3 {
                let bump = width * random.range(0.22, 0.36)
                let x = center.x + random.range(-0.3, 0.3) * width
                path.addEllipse(in: CGRect(x: x - bump / 2, y: center.y - height / 2 - bump * 0.45, width: bump, height: bump))
            }
            layer.fill(path, with: .color(color))
        }
    }

    private func streaks(in context: inout GraphicsContext, size: CGSize, random: inout SeededRandom,
                         count: Int, length: CGFloat, color: Color, opacity: Double) {
        var layer = context
        layer.opacity = opacity
        let slant = length * 0.25
        for _ in 0..<count {
            let x = random.range(-20, size.width + 20)
            let y = random.range(size.height * 0.1, size.height)
            let l = length * random.range(0.6, 1.3)
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - slant, y: y + l))
            layer.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: random.range(0.8, 1.6), lineCap: .round))
        }
    }

    private func haze(in context: inout GraphicsContext, size: CGSize, color: Color, y: CGFloat, opacity: Double) {
        var layer = context
        layer.addFilter(.blur(radius: size.width * 0.2))
        layer.opacity = opacity
        layer.fill(Path(ellipseIn: CGRect(x: -size.width * 0.3, y: size.height * y - size.height * 0.15,
                                          width: size.width * 1.6, height: size.height * 0.3)), with: .color(color))
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
        var glow = context
        glow.addFilter(.blur(radius: 10))
        glow.stroke(path, with: .color(Color(red: 0.8, green: 0.8, blue: 1)), lineWidth: 8)
        context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
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
