import SwiftUI

// MARK: - Font Manager

class FontManager {
    static let shared = FontManager()
    
    private init() {}
    
    // MARK: - Font Names (Updated to match actual font files)
    private struct FontNames {
        // Using FormaDJRText for body text
        static let textRegular = "FormaDJRText-Regular"
        static let textMedium = "FormaDJRText-Medium"
        static let textBold = "FormaDJRText-Bold"
        static let textLight = "FormaDJRText-Light"
        static let textExtraLight = "FormaDJRText-ExtraLight"
        static let textBlack = "FormaDJRText-Black"
        static let textExtraBold = "FormaDJRText-ExtraBold"
        
        // Using FormaDJRDeck for UI elements
        static let deckRegular = "FormaDJRDeck-Regular"
        static let deckMedium = "FormaDJRDeck-Medium"
        static let deckBold = "FormaDJRDeck-Bold"
        static let deckLight = "FormaDJRDeck-Light"
        
        // Using FormaDJRDisplay for large titles
        static let displayRegular = "FormaDJRDisplay-Regular"
        static let displayMedium = "FormaDJRDisplay-Medium"
        static let displayBold = "FormaDJRDisplay-Bold"
        
        // Using FormaDJRBanner for headers
        static let bannerRegular = "FormaDJRBanner-Regular"
        static let bannerMedium = "FormaDJRBanner-Medium"
        static let bannerBold = "FormaDJRBanner-Bold"
    }
    
    // MARK: - Font Styles
    
    // Large titles (using Display variant for impact)
    static func largeTitle(weight: Font.Weight = .regular) -> Font {
        return customFont(size: 34, weight: weight, variant: .display)
    }
    
    // Titles (using Banner variant for headers)
    static func title(weight: Font.Weight = .regular) -> Font {
        return customFont(size: 28, weight: weight, variant: .banner)
    }
    
    static func title2(weight: Font.Weight = .regular) -> Font {
        return customFont(size: 22, weight: weight, variant: .banner)
    }
    
    static func title3(weight: Font.Weight = .regular) -> Font {
        return customFont(size: 20, weight: weight, variant: .deck)
    }
    
    // Headlines (using Deck variant for UI)
    static func headline(weight: Font.Weight = .semibold) -> Font {
        return customFont(size: 17, weight: weight, variant: .deck)
    }
    
    // Body text (using Text variant for readability)
    static func body(weight: Font.Weight = .regular) -> Font {
        return customFont(size: 17, weight: weight, variant: .text)
    }
    
    static func callout(weight: Font.Weight = .regular) -> Font {
        return customFont(size: 16, weight: weight, variant: .text)
    }
    
    // Small text (using Text variant)
    static func subheadline(weight: Font.Weight = .regular) -> Font {
        return customFont(size: 15, weight: weight, variant: .text)
    }
    
    static func footnote(weight: Font.Weight = .regular) -> Font {
        return customFont(size: 13, weight: weight, variant: .text)
    }
    
    static func caption(weight: Font.Weight = .regular) -> Font {
        return customFont(size: 12, weight: weight, variant: .text)
    }
    
    static func caption2(weight: Font.Weight = .regular) -> Font {
        return customFont(size: 11, weight: weight, variant: .text)
    }
    
    // MARK: - Font Variant Types
    
    private enum FontVariant {
        case text, deck, display, banner
    }
    
    // MARK: - Custom Font Helper
    
    private static func customFont(size: CGFloat, weight: Font.Weight, variant: FontVariant = .text) -> Font {
        let fontName = fontNameForWeightAndVariant(weight, variant: variant)
        
        // Try to load custom font, fallback to system font if unavailable
        if UIFont(name: fontName, size: size) != nil {
            return Font.custom(fontName, size: size)
        } else {
            // Fallback to system font if custom font is not available
             ("⚠️ Font '\(fontName)' not found, using system font")
            return Font.system(size: size, weight: weight)
        }
    }
    
    private static func fontNameForWeightAndVariant(_ weight: Font.Weight, variant: FontVariant) -> String {
        switch variant {
        case .text:
            switch weight {
            case .black:
                return FontNames.textBlack
            case .heavy, .bold:
                return FontNames.textBold
            case .semibold:
                return FontNames.textBold // Use bold as fallback for semibold
            case .medium:
                return FontNames.textMedium
            case .light:
                return FontNames.textLight
            case .thin, .ultraLight:
                return FontNames.textExtraLight
            default:
                return FontNames.textRegular
            }
        case .deck:
            switch weight {
            case .black, .heavy, .bold, .semibold:
                return FontNames.deckBold
            case .medium:
                return FontNames.deckMedium
            case .light, .thin, .ultraLight:
                return FontNames.deckLight
            default:
                return FontNames.deckRegular
            }
        case .display:
            switch weight {
            case .black, .heavy, .bold, .semibold:
                return FontNames.displayBold
            case .medium:
                return FontNames.displayMedium
            default:
                return FontNames.displayRegular
            }
        case .banner:
            switch weight {
            case .black, .heavy, .bold, .semibold:
                return FontNames.bannerBold
            case .medium:
                return FontNames.bannerMedium
            default:
                return FontNames.bannerRegular
            }
        }
    }
    
    // MARK: - Font Availability Check
    
    static func isCustomFontAvailable() -> Bool {
        return UIFont(name: FontNames.textRegular, size: 16) != nil
    }
    
    // MARK: - List Available Fonts (for debugging)
    
    static func listAvailableFonts() {
         ("📝 Available Font Families:")
        for family in UIFont.familyNames.sorted() {
            let names = UIFont.fontNames(forFamilyName: family)
             ("Family: \(family)")
            for name in names {
                 ("  - \(name)")
            }
        }
    }
    
    static func checkFormaFonts() {
         ("🔍 Checking Forma DJR Font Availability:")
        let formaFonts = [
            FontNames.textRegular,
            FontNames.textMedium,
            FontNames.textBold,
            FontNames.deckRegular,
            FontNames.deckMedium,
            FontNames.deckBold,
            FontNames.displayRegular,
            FontNames.bannerRegular
        ]
        
        for fontName in formaFonts {
            let isAvailable = UIFont(name: fontName, size: 16) != nil
             ("  \(fontName): \(isAvailable ? "✅ Available" : "❌ Not Found")")
        }
    }
}

// MARK: - Font Extension for SwiftUI

extension Font {
    // Convenience methods using FontManager
    static func forma(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        switch style {
        case .largeTitle:
            return FontManager.largeTitle(weight: weight)
        case .title:
            return FontManager.title(weight: weight)
        case .title2:
            return FontManager.title2(weight: weight)
        case .title3:
            return FontManager.title3(weight: weight)
        case .headline:
            return FontManager.headline(weight: weight)
        case .body:
            return FontManager.body(weight: weight)
        case .callout:
            return FontManager.callout(weight: weight)
        case .subheadline:
            return FontManager.subheadline(weight: weight)
        case .footnote:
            return FontManager.footnote(weight: weight)
        case .caption:
            return FontManager.caption(weight: weight)
        case .caption2:
            return FontManager.caption2(weight: weight)
        @unknown default:
            return FontManager.body(weight: weight)
        }
    }
}
