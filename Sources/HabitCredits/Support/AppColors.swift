import SwiftUI

enum AppColors {
    static let brandGreen = Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255) // #10B981
    static let brandTeal = Color(red: 13 / 255, green: 148 / 255, blue: 136 / 255) // #0D9488
    static let slate900 = Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255)
    static let slate700 = Color(red: 51 / 255, green: 65 / 255, blue: 85 / 255)
    static let slate500 = Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255)
    static let bg = Color(red: 248 / 255, green: 250 / 255, blue: 252 / 255)
    static let border = Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255)
    static let red600 = Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255)
    static let amber600 = Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255)

    static func color(hex: String) -> Color? {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard raw.count == 6 else { return nil }
        guard let value = Int(raw, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

