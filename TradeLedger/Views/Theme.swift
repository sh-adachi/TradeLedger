import SwiftUI
import TradeLedgerCore

enum Palette {
    static let background = Color(hex: 0xF6F7F3)
    static let card = Color.white
    static let ink = Color(hex: 0x172F32)
    static let muted = Color(hex: 0x6D7C7C)
    static let accent = Color(hex: 0x087F72)
    static let positive = Color(hex: 0x087F72)
    static let negative = Color(hex: 0xC4584D)
    static let border = Color(hex: 0xE4EAE5)
    static let mint = Color(hex: 0xE6F3EC)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

enum Money {
    static func text(_ value: Int64, signed: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ja_JP")
        let digits = formatter.string(from: NSNumber(value: value.magnitude)) ?? "0"
        return (value < 0 ? "−" : signed && value > 0 ? "+" : "") + "¥" + digits
    }

    static func compact(_ value: Int64) -> String {
        if abs(value) >= 100_000_000 { return String(format: "%.1f億", Double(value) / 100_000_000) }
        if abs(value) >= 10_000 { return String(format: "%.0f万", Double(value) / 10_000) }
        return String(value)
    }

    static func parse(_ string: String) -> Int64? {
        let normalized = (string.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? string)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = normalized.replacingOccurrences(of: ",", with: "")
        guard !digits.isEmpty, digits.utf8.allSatisfy({ (48...57).contains($0) }),
              let value = Int64(digits), value <= 1_000_000_000_000 else { return nil }
        return value
    }
}

struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.border.opacity(0.7), lineWidth: 1))
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(Palette.ink)
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(Palette.muted) }
        }
    }
}

struct ProfitText: View {
    let amount: Int64
    var size: CGFloat = 20
    var body: some View {
        Text(Money.text(amount, signed: true))
            .font(.system(size: size, weight: .semibold, design: .rounded)).monospacedDigit()
            .foregroundStyle(amount < 0 ? Palette.negative : Palette.positive)
            .lineLimit(1).minimumScaleFactor(0.6)
    }
}

struct BrandMark: View {
    var size: CGFloat = 40
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3).fill(Palette.ink)
            Image(systemName: "chart.xyaxis.line").font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(Color(hex: 0xA4E6C5))
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

enum DisplayDate {
    static func string(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = LedgerCalendar.calendar
        formatter.timeZone = LedgerCalendar.calendar.timeZone
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

struct MonthNavigator: View {
    @Binding var month: Date
    var body: some View {
        HStack(spacing: 18) {
            Button { month = LedgerCalendar.addingMonths(-1, to: month) } label: {
                Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold)).frame(width: 36, height: 36)
            }.accessibilityLabel("前の月")
            Text(DisplayDate.string(month, "yyyy年 M月")).font(.system(.subheadline, design: .rounded, weight: .semibold))
                .frame(maxWidth: .infinity)
            Button { month = LedgerCalendar.addingMonths(1, to: month) } label: {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).frame(width: 36, height: 36)
            }.disabled(LedgerCalendar.monthStart(month) >= LedgerCalendar.monthStart(Date()))
                .accessibilityLabel("次の月")
        }.foregroundStyle(Palette.ink)
    }
}

struct EmptyLedgerView: View {
    var title = "今日から、積み重ねよう。"
    var message = "取引後の資産額を記録すると、\nあなたのトレードの軌跡が見えてきます。"
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 30, weight: .light))
                .foregroundStyle(Palette.accent).frame(width: 70, height: 70).background(Palette.mint, in: Circle())
            Text(title).font(.headline).foregroundStyle(Palette.ink)
            Text(message).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Palette.muted).lineSpacing(4)
        }.frame(maxWidth: .infinity).padding(.vertical, 25)
    }
}
