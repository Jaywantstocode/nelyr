import AppKit
import SwiftUI

/// The single source of truth for Nelyr's visual language.
enum NelyrBrand {
    static let graphite = Color(red: 11 / 255, green: 13 / 255, blue: 18 / 255)
    static let violet = Color(red: 124 / 255, green: 92 / 255, blue: 1)
    static let cyan = Color(red: 77 / 255, green: 232 / 255, blue: 1)
    static let coolWhite = Color(red: 244 / 255, green: 245 / 255, blue: 247 / 255)

    // Semantic colors stay centralized so states remain consistent.
    static let accent = violet
    static let success = adaptive(
        light: NSColor(calibratedRed: 0.02, green: 0.43, blue: 0.51, alpha: 1),
        dark: NSColor(calibratedRed: 77 / 255, green: 232 / 255, blue: 1, alpha: 1)
    )
    static let warning = adaptive(
        light: NSColor(calibratedRed: 0.68, green: 0.38, blue: 0.05, alpha: 1),
        dark: NSColor(calibratedRed: 0.94, green: 0.62, blue: 0.27, alpha: 1)
    )
    static let danger = adaptive(
        light: NSColor(calibratedRed: 0.75, green: 0.12, blue: 0.20, alpha: 1),
        dark: NSColor(calibratedRed: 0.98, green: 0.35, blue: 0.42, alpha: 1)
    )

    static let signalGradient = LinearGradient(
        colors: [violet, cyan],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let signalAngularGradient = AngularGradient(
        colors: [violet, cyan, violet],
        center: .center
    )

    static let ambientBackground = LinearGradient(
        colors: [violet.opacity(0.11), cyan.opacity(0.055), .clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? dark
                : light
        })
    }
}

/// The waveform → N → knowledge-node mark used inside the product UI.
struct NelyrSignalMark: View {
    var lineWidth: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let point: (CGFloat, CGFloat) -> CGPoint = {
                CGPoint(x: $0 * width, y: $1 * height)
            }

            ZStack {
                Path { path in
                    path.move(to: point(0.02, 0.57))
                    path.addLine(to: point(0.10, 0.57))
                    path.addLine(to: point(0.15, 0.64))
                    path.addLine(to: point(0.21, 0.39))
                    path.addLine(to: point(0.27, 0.72))
                    path.addLine(to: point(0.33, 0.57))
                    path.addLine(to: point(0.39, 0.57))
                    path.addLine(to: point(0.39, 0.14))
                    path.addLine(to: point(0.68, 0.84))
                    path.addLine(to: point(0.68, 0.20))
                    path.addLine(to: point(0.76, 0.14))
                    path.addLine(to: point(0.76, 0.44))
                    path.addLine(to: point(0.91, 0.68))
                    path.addLine(to: point(0.97, 0.68))
                }
                .stroke(
                    NelyrBrand.signalGradient,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                Circle()
                    .fill(NelyrBrand.cyan)
                    .frame(width: lineWidth * 2.3, height: lineWidth * 2.3)
                    .position(point(0.97, 0.68))
            }
        }
        .aspectRatio(1.7, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct NelyrBrandBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(colorScheme == .dark ? NelyrBrand.graphite : NelyrBrand.coolWhite)
                .shadow(
                    color: NelyrBrand.violet.opacity(colorScheme == .dark ? 0.16 : 0.10),
                    radius: 8,
                    y: 3
                )
            NelyrSignalMark(lineWidth: max(2, size * 0.065))
                .padding(size * 0.15)
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(
                    colorScheme == .dark
                        ? Color.white.opacity(0.10)
                        : Color.black.opacity(0.08)
                )
        }
        .accessibilityLabel("Nelyr")
    }
}
