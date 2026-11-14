import SwiftUI

/// Small deterministic random generator, so a motif looks the same every time
/// it is drawn with the same seed.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> CGFloat { CGFloat(Double(next() >> 11) / Double(1 << 53)) }
    mutating func range(_ lower: CGFloat, _ upper: CGFloat) -> CGFloat { lower + (upper - lower) * unit() }
}

/// The background picture: a drawn motif in the theme's colors, or the user's photo.
struct WallpaperBackground: View {
    let theme: WallpaperTheme
    let artwork: Artwork
    var photo: UIImage?
    var framing = PhotoEntry()
    /// How much a photo is darkened, 0...1.
    var dimming: Double = 0.5
    /// Changes the random layout; the wallpaper uses the day of the year,
    /// so the motif shifts a little every day.
    var seed: UInt64 = 1

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.background.top.color, theme.background.bottom.color],
                startPoint: .top,
                endPoint: .bottom
            )
            motif
        }
        .clipped()
    }

    @ViewBuilder
    private var motif: some View {
        switch artwork {
        case .plain:
            EmptyView()
        case .aurora:
            Canvas { context, size in drawAurora(in: &context, size: size) }
        case .dunes:
            Canvas { context, size in drawDunes(in: &context, size: size) }
        case .stars:
            Canvas { context, size in drawStars(in: &context, size: size) }
        case .waves:
            Canvas { context, size in drawWaves(in: &context, size: size) }
        case .bokeh:
            Canvas { context, size in drawBokeh(in: &context, size: size) }
        case .photo:
            if let photo {
                PhotoFill(image: photo, framing: framing)
                // Darken the lower part more, so the agenda stays readable on any photo.
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.2 * dimming), location: 0),
                        .init(color: .black.opacity(0.3 * dimming), location: 0.30),
                        .init(color: .black.opacity(min(1.1 * dimming, 0.9)), location: 0.60),
                        .init(color: .black.opacity(min(1.3 * dimming, 0.92)), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Canvas { context, size in drawAurora(in: &context, size: size) }
            }
        }
    }

    private var accents: [Color] { theme.accents.map(\.color) }

    // MARK: Motifs

    /// Soft, blurred bands of light across the upper half.
    private func drawAurora(in context: inout GraphicsContext, size: CGSize) {
        var random = SeededRandom(seed: seed)
        var layer = context
        layer.addFilter(.blur(radius: size.width * 0.12))
        for index in 0..<5 {
            let color = accents[index % accents.count]
            let width = size.width * random.range(0.9, 1.6)
            let height = size.height * random.range(0.12, 0.22)
            let center = CGPoint(x: size.width * random.range(0.1, 0.9), y: size.height * random.range(0.08, 0.62))
            var band = layer
            band.translateBy(x: center.x, y: center.y)
            band.rotate(by: .degrees(Double(random.range(-28, 28))))
            band.opacity = Double(random.range(0.35, 0.65))
            band.fill(Path(ellipseIn: CGRect(x: -width / 2, y: -height / 2, width: width, height: height)), with: .color(color))
        }
    }

    /// Layered hills, lighter in the back and darker in front.
    private func drawDunes(in context: inout GraphicsContext, size: CGSize) {
        var random = SeededRandom(seed: seed)
        let layers = 5
        for index in 0..<layers {
            let progress = CGFloat(index) / CGFloat(layers - 1)
            let baseY = size.height * (0.42 + 0.13 * CGFloat(index))
            let amplitude = size.height * random.range(0.025, 0.06)
            let phase = random.range(0, .pi * 2)
            let frequency = random.range(1.1, 2.2)

            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height))
            for step in stride(from: CGFloat(0), through: size.width, by: 4) {
                let x = step / size.width
                let y = baseY + sin(x * .pi * frequency + phase) * amplitude + sin(x * .pi * 5.3 + phase) * amplitude * 0.25
                path.addLine(to: CGPoint(x: step, y: y))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()

            let color = accents[index % accents.count]
            context.fill(path, with: .linearGradient(
                Gradient(colors: [color.opacity(0.55 - 0.25 * progress), theme.background.bottom.color.opacity(0.35 + 0.6 * progress)]),
                startPoint: CGPoint(x: 0, y: baseY - amplitude),
                endPoint: CGPoint(x: 0, y: size.height)
            ))
        }
    }

    /// A starry sky with a few brighter stars and a faint glow at the horizon.
    private func drawStars(in context: inout GraphicsContext, size: CGSize) {
        var random = SeededRandom(seed: seed)
        let glow = Path(ellipseIn: CGRect(x: -size.width * 0.3, y: size.height * 0.72, width: size.width * 1.6, height: size.height * 0.6))
        var glowLayer = context
        glowLayer.addFilter(.blur(radius: size.width * 0.15))
        glowLayer.fill(glow, with: .color(accents[0].opacity(0.45)))

        let starColor: Color = theme.isLight ? theme.text.color : .white
        for _ in 0..<240 {
            let point = CGPoint(x: random.range(0, size.width), y: random.range(0, size.height * 0.95))
            let radius = random.unit() > 0.94 ? random.range(1.3, 2.2) : random.range(0.35, 1.0)
            var star = context
            star.opacity = Double(random.range(0.35, 0.95))
            star.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(starColor))
        }
    }

    /// Thin flowing lines, like a calm sea or a topographic map.
    private func drawWaves(in context: inout GraphicsContext, size: CGSize) {
        var random = SeededRandom(seed: seed)
        let lines = 26
        let phase = random.range(0, .pi * 2)
        let tilt = random.range(-0.08, 0.08)
        for index in 0..<lines {
            let progress = CGFloat(index) / CGFloat(lines - 1)
            let baseY = size.height * (0.05 + 0.95 * progress)
            var path = Path()
            for step in stride(from: CGFloat(0), through: size.width, by: 4) {
                let x = step / size.width
                let y = baseY
                    + sin(x * .pi * 2.2 + phase + progress * 3) * size.height * 0.018
                    + sin(x * .pi * 0.8 + progress * 6) * size.height * 0.03
                    + (x - 0.5) * size.height * tilt
                if step == 0 { path.move(to: CGPoint(x: step, y: y)) } else { path.addLine(to: CGPoint(x: step, y: y)) }
            }
            let color = accents[index % accents.count]
            context.stroke(path, with: .color(color.opacity(0.18 + 0.3 * Double(progress))), lineWidth: 1.4)
        }
    }

    /// Out-of-focus circles of light.
    private func drawBokeh(in context: inout GraphicsContext, size: CGSize) {
        var random = SeededRandom(seed: seed)
        var soft = context
        soft.addFilter(.blur(radius: size.width * 0.02))
        for index in 0..<26 {
            let radius = size.width * random.range(0.04, 0.17)
            let center = CGPoint(x: random.range(-0.1, 1.1) * size.width, y: random.range(-0.05, 1.05) * size.height)
            var light = soft
            light.opacity = Double(random.range(0.12, 0.4))
            let color = accents[index % accents.count]
            light.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
        }
    }
}

/// Fills its frame with a photo, zoomed and moved so the photo's focus point
/// sits as close to the middle as the photo's edges allow.
struct PhotoFill: View {
    let image: UIImage
    let framing: PhotoEntry

    var body: some View {
        GeometryReader { proxy in
            let rect = Self.frame(imageSize: image.size, in: proxy.size, framing: framing)
            Image(uiImage: image)
                .resizable()
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .clipped()
    }

    /// Where the image is drawn inside a frame of `size`, in the frame's coordinates.
    static func frame(imageSize: CGSize, in size: CGSize, framing: PhotoEntry) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return CGRect(origin: .zero, size: size) }
        let zoom = min(max(framing.zoom, PhotoEntry.zoomRange.lowerBound), PhotoEntry.zoomRange.upperBound)
        let fill = max(size.width / imageSize.width, size.height / imageSize.height) * CGFloat(zoom)
        let drawn = CGSize(width: imageSize.width * fill, height: imageSize.height * fill)
        func origin(_ focus: Double, drawn: CGFloat, frame: CGFloat) -> CGFloat {
            let wanted = frame / 2 - CGFloat(focus) * drawn
            return min(0, max(frame - drawn, wanted))
        }
        return CGRect(
            x: origin(framing.focusX, drawn: drawn.width, frame: size.width),
            y: origin(framing.focusY, drawn: drawn.height, frame: size.height),
            width: drawn.width,
            height: drawn.height
        )
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack {
            ForEach(Artwork.allCases) { artwork in
                WallpaperBackground(theme: .night, artwork: artwork)
                    .frame(width: 150, height: 325)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding()
    }
}
