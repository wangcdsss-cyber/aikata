import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct AppThemePreset: Identifiable, Equatable {
    let id: String
    let name: String
    let primaryHex: String
    let secondaryHex: String

    var primary: Color { Color(hex: primaryHex) }
    var secondary: Color { Color(hex: secondaryHex) }

    static let `default` = AppThemePreset(
        id: "sunset",
        name: "Sunset",
        primaryHex: "#FF6B6B",
        secondaryHex: "#FFD166"
    )

    static let all: [AppThemePreset] = [
        .default,
        AppThemePreset(id: "ocean", name: "Ocean", primaryHex: "#2D9CDB", secondaryHex: "#56CCF2"),
        AppThemePreset(id: "forest", name: "Forest", primaryHex: "#27AE60", secondaryHex: "#6FCF97"),
        AppThemePreset(id: "grape", name: "Grape", primaryHex: "#9B51E0", secondaryHex: "#BB6BD9"),
        AppThemePreset(id: "rose", name: "Rose", primaryHex: "#EB5757", secondaryHex: "#F2994A"),
        AppThemePreset(id: "mint", name: "Mint", primaryHex: "#00BFA6", secondaryHex: "#2F80ED"),
        AppThemePreset(id: "amber", name: "Amber", primaryHex: "#F2994A", secondaryHex: "#F2C94C"),
        AppThemePreset(id: "sky", name: "Sky", primaryHex: "#56CCF2", secondaryHex: "#2D9CDB"),
        AppThemePreset(id: "slate", name: "Slate", primaryHex: "#64748B", secondaryHex: "#94A3B8"),
        AppThemePreset(id: "sakura", name: "Sakura", primaryHex: "#FF5DA2", secondaryHex: "#FFB4D2"),
        AppThemePreset(id: "indigo", name: "Indigo", primaryHex: "#4F46E5", secondaryHex: "#A5B4FC"),
        AppThemePreset(id: "citrus", name: "Citrus", primaryHex: "#84CC16", secondaryHex: "#FDE047")
    ]
}

enum ThemeAppearanceMode: Int, CaseIterable, Identifiable {
    case system = 0
    case light = 1
    case dark = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct ThemeResolvedColors: Equatable {
    let accent: Color
    let accentSecondary: Color
    let background: Color
    let surface: Color
    let textPrimary: Color
    let textSecondary: Color
    let divider: Color

    func contrastText(on color: Color) -> Color {
#if canImport(UIKit)
        let ui = UIColor(color)
        let white = UIColor.white
        let black = UIColor.black
        return ui.relativeLuminance() < 0.45 ? Color(white) : Color(black)
#else
        return Color.white
#endif
    }
}

final class ThemeStore: ObservableObject {
    @Published var selectedThemeId: String {
        didSet { UserDefaults.standard.set(selectedThemeId, forKey: Self.keyThemeId) }
    }
    @Published var appearanceModeRaw: Int {
        didSet { UserDefaults.standard.set(appearanceModeRaw, forKey: Self.keyAppearanceMode) }
    }

    static let keyThemeId = "theme_selected_id"
    static let keyAppearanceMode = "theme_appearance_mode"

    init() {
        selectedThemeId = UserDefaults.standard.string(forKey: Self.keyThemeId) ?? AppThemePreset.default.id
        appearanceModeRaw = UserDefaults.standard.object(forKey: Self.keyAppearanceMode) as? Int ?? ThemeAppearanceMode.system.rawValue
    }

    var appearanceMode: ThemeAppearanceMode {
        ThemeAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    var preferredColorScheme: ColorScheme? {
        appearanceMode.preferredColorScheme
    }

    var selectedTheme: AppThemePreset {
        AppThemePreset.all.first(where: { $0.id == selectedThemeId }) ?? AppThemePreset.default
    }

    func reset() {
        selectedThemeId = AppThemePreset.default.id
        appearanceModeRaw = ThemeAppearanceMode.system.rawValue
    }

    func select(theme: AppThemePreset) {
        selectedThemeId = theme.id
    }

    func setAppearanceMode(_ mode: ThemeAppearanceMode) {
        appearanceModeRaw = mode.rawValue
    }

    func resolvedColors(for scheme: ColorScheme) -> ThemeResolvedColors {
        let theme = selectedTheme
        if scheme == .dark {
            return ThemeResolvedColors(
                accent: theme.primary,
                accentSecondary: theme.secondary,
                background: Color.black,
                surface: Color.white.opacity(0.06),
                textPrimary: Color.white,
                textSecondary: Color.white.opacity(0.78),
                divider: Color.white.opacity(0.14)
            )
        }
        return ThemeResolvedColors(
            accent: theme.primary,
            accentSecondary: theme.secondary,
            background: Color.white,
            surface: Color.black.opacity(0.04),
            textPrimary: Color.black,
            textSecondary: Color.black.opacity(0.72),
            divider: Color.black.opacity(0.12)
        )
    }
}

#if canImport(UIKit)
private extension UIColor {
    func relativeLuminance() -> CGFloat {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return 0 }
        func f(_ c: CGFloat) -> CGFloat {
            c <= 0.03928 ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)
    }
}
#endif
