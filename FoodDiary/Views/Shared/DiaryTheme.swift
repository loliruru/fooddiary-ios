import SwiftUI
import UIKit

enum DiaryTheme {
    static let canvas = adaptive(light: 0xF7F5ED, dark: 0x141B18)
    static let surface = adaptive(light: 0xFFFCF5, dark: 0x1E2823)
    static let text = adaptive(light: 0x1E3027, dark: 0xF4F0E3)
    static let secondaryText = adaptive(light: 0x526459, dark: 0xB8C5B9)
    static let border = adaptive(light: 0xDDDCD0, dark: 0x38473E)
    static let accent = adaptive(light: 0x2B5846, dark: 0xA6D4B4)
    static let onAccent = adaptive(light: 0xFFFCF5, dark: 0x14241B)
    static let accentSurface = adaptive(light: 0xE6EEE0, dark: 0x25392E)
    static let observation = adaptive(light: 0x884931, dark: 0xF1B199)
    static let observationSurface = adaptive(light: 0xF6E5DB, dark: 0x3C2B25)

    static let pageTitle = Font.system(.largeTitle, design: .rounded, weight: .semibold)
    static let cornerRadius: CGFloat = 20

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
