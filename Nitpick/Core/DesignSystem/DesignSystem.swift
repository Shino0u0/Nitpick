import SwiftUI

/// Quiet Utility palette (SPEC 4.1). Dark Mode keeps the quiet hierarchy:
/// canvases darken, ink lightens, the lime accent stays restrained.
enum NP {
    static let canvas = dynamic(light: 0xF7F5EF, dark: 0x1B1E1D)
    static let canvasSecondary = dynamic(light: 0xE9E7E0, dark: 0x242827)
    static let rail = dynamic(light: 0x202624, dark: 0x151817)
    static let ink = dynamic(light: 0x1C211F, dark: 0xECEAE4)
    static let inkSecondary = dynamic(light: 0x5A605D, dark: 0x9BA19E)
    static let accent = Color(hex: 0xC8FF4D)
    static let success = dynamic(light: 0xDFF8B2, dark: 0x33421B)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x252928)
    static let border = dynamic(light: 0x202624, dark: 0xECEAE4).opacity(0.14)

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return NSColor(hex: isDark ? dark : light)
            }
        )
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(nsColor: NSColor(hex: hex))
    }
}

/// White card with a thin border, no heavy shadow.
struct NPCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(NP.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10).strokeBorder(NP.border)
            )
    }
}

/// Small uppercase section label.
struct NPEyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .kerning(0.8)
            .foregroundStyle(NP.inkSecondary)
    }
}

struct NPCapsuleButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                prominent ? NP.rail : NP.canvasSecondary, in: Capsule()
            )
            .foregroundStyle(prominent ? NP.accent : NP.ink)
            .overlay(Capsule().strokeBorder(NP.border))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension View {
    func npCard() -> some View { modifier(NPCard()) }
}
