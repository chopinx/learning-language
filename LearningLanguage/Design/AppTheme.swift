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

extension Color {
    // Primary - Deep teal (language learning / focus)
    static let themePrimary = Color(hex: "0F6A74")!
    static let themePrimaryDark = Color(hex: "133D5A")!

    // Semantic
    static let themeSuccess = Color(hex: "22C55E")!
    static let themeWarning = Color(hex: "F59E0B")!
    static let themeError = Color(hex: "EF4444")!

    // Neutrals
    static let themeTextPrimary = Color(hex: "1E293B")!
    static let themeTextSecondary = Color(hex: "64748B")!
    static let themeTextTertiary = Color(hex: "94A3B8")!
    static let themeBorder = Color(hex: "E2E8F0")!

    // Diff token colors
    static let diffCorrectBg = Color(hex: "DFF3E6")!
    static let diffCorrectText = Color(hex: "1F6A43")!
    static let diffMissingBg = Color(hex: "FDEAE7")!
    static let diffMissingText = Color(hex: "B74838")!
    static let diffWrongBg = Color(hex: "FFF1DE")!
    static let diffWrongText = Color(hex: "AB6913")!
    static let diffExtraBg = Color(hex: "ECEAFF")!
    static let diffExtraText = Color(hex: "5E4CC7")!

    // Gradient
    static var themePrimaryGradient: LinearGradient {
        LinearGradient(
            colors: [.themePrimaryDark, .themePrimary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - View Modifiers

struct ThemedCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.systemBackground))
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

// MARK: - Styled Progress Bar

struct StyledProgressBar: View {
    let progress: Double
    let completed: Int
    let total: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color.themePrimary)
                        .frame(width: max(0, geo.size.width * progress), height: 8)
                }
            }
            .frame(height: 8)

            Text("\(completed)/\(total)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.themeTextTertiary)
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

// MARK: - Badge Component

struct BadgeView: View {
    let text: String
    let foregroundColor: Color
    let backgroundColor: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor, in: Capsule())
    }
}
