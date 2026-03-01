import SwiftUI

// MARK: - Color(hex:) Initializer

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - App Color Theme
// Fresh, modern palette matching ProjectX design language

extension Color {
    // MARK: - Primary Colors
    /// Main brand color - Fresh emerald green
    static let themePrimary = Color(hex: "10B981") ?? Color.green
    /// Darker variant for contrast
    static let themePrimaryDark = Color(hex: "059669") ?? Color.green

    // MARK: - Secondary Colors
    /// Warm accent - Coral orange
    static let themeSecondary = Color(hex: "F97316") ?? Color.orange
    /// Lighter variant
    static let themeSecondaryLight = Color(hex: "FB923C") ?? Color.orange

    // MARK: - Semantic Colors
    /// Success - Bright green
    static let themeSuccess = Color(hex: "22C55E") ?? Color.green
    /// Warning - Amber
    static let themeWarning = Color(hex: "F59E0B") ?? Color.yellow
    /// Error - Rose red
    static let themeError = Color(hex: "EF4444") ?? Color.red
    /// Info - Sky blue
    static let themeInfo = Color(hex: "0EA5E9") ?? Color.blue

    // MARK: - Neutral Colors (adaptive for dark/light mode)
    #if os(iOS)
    static let themeBackground = Color(.systemGroupedBackground)
    static let themeCardBackground = Color(.systemBackground)
    static let themeBorder = Color(.separator)
    static let themeTextPrimary = Color(.label)
    static let themeTextSecondary = Color(.secondaryLabel)
    static let themeTextTertiary = Color(.tertiaryLabel)
    static let themeGray5 = Color(.systemGray5)
    static let themeGray4 = Color(.systemGray4)
    static let themeSecondaryBackground = Color(.secondarySystemBackground)
    #elseif os(macOS)
    static let themeBackground = Color(nsColor: .controlBackgroundColor)
    static let themeCardBackground = Color(nsColor: .windowBackgroundColor)
    static let themeBorder = Color(nsColor: .separatorColor)
    static let themeTextPrimary = Color(nsColor: .labelColor)
    static let themeTextSecondary = Color(nsColor: .secondaryLabelColor)
    static let themeTextTertiary = Color(nsColor: .tertiaryLabelColor)
    static let themeGray5 = Color(nsColor: .separatorColor)
    static let themeGray4 = Color(nsColor: .gridColor)
    static let themeSecondaryBackground = Color(nsColor: .controlBackgroundColor)
    #endif

    // MARK: - Diff Token Colors
    static let diffCorrectBg = Color(hex: "D1FAE5") ?? Color.green.opacity(0.2)
    static let diffCorrectText = Color(hex: "065F46") ?? Color.green
    static let diffMissingBg = Color(hex: "FEE2E2") ?? Color.red.opacity(0.2)
    static let diffMissingText = Color(hex: "991B1B") ?? Color.red
    static let diffWrongBg = Color(hex: "FEF3C7") ?? Color.yellow.opacity(0.2)
    static let diffWrongText = Color(hex: "92400E") ?? Color.orange
    static let diffExtraBg = Color(hex: "EDE9FE") ?? Color.purple.opacity(0.2)
    static let diffExtraText = Color(hex: "5B21B6") ?? Color.purple

    // MARK: - Gradient
    static var themePrimaryGradient: LinearGradient {
        LinearGradient(
            colors: [themePrimary, Color(hex: "14B8A6") ?? Color.teal],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Modifiers

struct ThemedCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.themeCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func appCard() -> some View {
        modifier(ThemedCardModifier())
    }
}

// MARK: - Diff Token Chip

struct DiffTokenChip: View {
    let text: String
    let kind: DiffToken.Kind

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(bgColor, in: RoundedRectangle(cornerRadius: 8))
    }

    private var bgColor: Color {
        switch kind {
        case .correct: return .diffCorrectBg
        case .missing: return .diffMissingBg
        case .wrong:   return .diffWrongBg
        case .extra:   return .diffExtraBg
        }
    }

    private var textColor: Color {
        switch kind {
        case .correct: return .diffCorrectText
        case .missing: return .diffMissingText
        case .wrong:   return .diffWrongText
        case .extra:   return .diffExtraText
        }
    }
}

// MARK: - Diff Summary Chips

struct DiffSummaryChips: View {
    let result: DiffResult

    var body: some View {
        HStack(spacing: 8) {
            if result.summary.missingCount > 0 {
                ChipView(
                    text: "missing \(result.summary.missingCount)",
                    foregroundColor: .diffMissingText,
                    backgroundColor: .diffMissingBg
                )
            }
            if result.summary.wrongCount > 0 {
                ChipView(
                    text: "wrong \(result.summary.wrongCount)",
                    foregroundColor: .diffWrongText,
                    backgroundColor: .diffWrongBg
                )
            }
            if result.summary.extraCount > 0 {
                ChipView(
                    text: "extra \(result.summary.extraCount)",
                    foregroundColor: .diffExtraText,
                    backgroundColor: .diffExtraBg
                )
            }
        }
    }
}


// MARK: - Relative Time Formatter

enum RelativeTimeFormatter {
    static func string(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60) min ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        if seconds < 172800 { return "Yesterday" }
        return "\(seconds / 86400) days ago"
    }
}

// MARK: - File Size Formatter

enum FileSizeFormatter {
    static func string(from bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return "\(bytes / 1024) KB" }
        return String(format: "%.0f MB", Double(bytes) / 1_048_576.0)
    }
}

// MARK: - Chip Component

struct ChipView: View {
    let text: String
    let foregroundColor: Color
    let backgroundColor: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor, in: Capsule())
    }
}

