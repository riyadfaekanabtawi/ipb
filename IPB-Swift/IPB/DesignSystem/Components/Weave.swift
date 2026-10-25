import SwiftUI

/// Static, very subtle plain-weave texture drawn with Canvas. Cheap: rendered once per size.
struct WeaveTexture: View {
    var spacing: CGFloat = 14
    var ink: Color = Theme.brandDeep.opacity(0.035)

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let shading = GraphicsContext.Shading.color(self.ink)
            var x: CGFloat = 0
            var column = 0
            while x < size.width {
                var y: CGFloat = 0
                var row = 0
                while y < size.height {
                    // Alternate over/under segments like a plain weave.
                    let horizontal = (row + column).isMultiple(of: 2)
                    let rect =
                        horizontal
                        ? CGRect(x: x + 2, y: y + spacing / 2 - 1, width: spacing - 4, height: 2)
                        : CGRect(x: x + spacing / 2 - 1, y: y + 2, width: 2, height: spacing - 4)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: shading)
                    y += spacing
                    row += 1
                }
                x += spacing
                column += 1
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Animated "loom" of flowing threads. Used on the login and dashboard hero.
struct ThreadField: View {
    var threadCount = 18
    var colors: [Color] = [Theme.thread, .white, Color(hex: 0x3FA7BD)]
    var speed: Double = 0.18

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * speed
            Canvas { context, size in
                for i in 0..<threadCount {
                    let p = Double(i) / Double(threadCount)
                    let baseY = size.height * (0.08 + 0.84 * p)
                    let amplitude = size.height * (0.03 + 0.05 * sin(p * .pi))
                    let frequency = 1.4 + 0.9 * sin(Double(i) * 1.7)
                    let phase = t * (0.6 + p) + Double(i)

                    var path = Path()
                    let steps = 48
                    for s in 0...steps {
                        let u = Double(s) / Double(steps)
                        let x = size.width * u
                        let y =
                            baseY + amplitude * sin(u * .pi * 2 * frequency + phase)
                            + amplitude * 0.35 * sin(u * .pi * 7 + phase * 1.3)
                        if s == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    let color = colors[i % colors.count]
                    let opacity = 0.10 + 0.22 * (0.5 + 0.5 * sin(phase * 0.7))
                    context.stroke(path, with: .color(color.opacity(opacity)), lineWidth: i % 5 == 0 ? 2.2 : 1)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Brand hero backdrop: teal gradient + flowing threads.
struct LoomBackdrop: View {
    var body: some View {
        ZStack {
            Theme.brandGradient
            ThreadField()
            RadialGradient(colors: [Theme.thread.opacity(0.25), .clear], center: .topTrailing, startRadius: 10, endRadius: 520)
        }
    }
}

#Preview {
    LoomBackdrop().frame(width: 900, height: 400)
}
