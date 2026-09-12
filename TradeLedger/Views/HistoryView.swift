import SwiftUI
import TradeLedgerCore

struct HistoryView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var month = LedgerCalendar.monthStart(Date())
    @State private var presentedRecord: HistoryRecordPresentation?

    private var days: [DailyPerformance] { store.analytics.days(inMonth: month) }
    private var currentMonth: Date { LedgerCalendar.monthStart(Date()) }
    private var monthlyProfit: Int64 { LedgerAnalytics.profit(for: days) }

    var body: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Card {
                        VStack(alignment: .leading, spacing: 20) {
                            monthNavigation
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("月間損益")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Palette.muted)
                                    ProfitText(amount: monthlyProfit, size: 30)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                }
                                Spacer(minLength: 8)
                                Text("\(days.count) 日の記録")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Palette.muted)
                            }
                            Divider()
                            monthCalendar
                            HStack(spacing: 14) {
                                legend("プラス", color: Palette.positive)
                                legend("マイナス", color: Palette.negative)
                                Spacer()
                                Text("日付をタップして記録")
                                    .font(.caption2)
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                    }

                    HStack {
                        SectionHeading(title: "日々の記録", subtitle: "DAILY ENTRIES")
                        Spacer()
                        Text("新しい順")
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                    }

                    if days.isEmpty {
                        Card {
                            VStack(spacing: 14) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundStyle(Palette.accent)
                                Text("この月の記録はまだありません")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                Text("口座残高を記録すると、日々の損益が\nカレンダーに積み重なっていきます。")
                                    .font(.subheadline)
                                    .foregroundStyle(Palette.muted)
                                    .multilineTextAlignment(.center)
                                Button("記録を追加") { addRecord() }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Palette.accent)
                                    .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(days.reversed()) { day in
                                Button { presentedRecord = HistoryRecordPresentation(record: day.record, date: day.date) } label: {
                                    recordRow(day)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("history.record")
                                .accessibilityLabel("\(fullDate(day.date))、損益\(Money.text(day.profit, signed: true))、残高\(Money.text(day.balance))。編集")
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 12)
            }
            .background(Palette.background)
            .foregroundStyle(Palette.ink)
            .navigationTitle("記録")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addRecord() } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .tint(Palette.accent)
                    .accessibilityLabel("記録を追加")
                    .accessibilityIdentifier("record.add")
                }
            }
            .sheet(item: $presentedRecord) { presentation in
                RecordEditorView(record: presentation.record, date: presentation.date)
                    .environmentObject(store)
            }
        }
    }

    private var monthNavigation: some View {
        HStack(spacing: 12) {
            Button { month = LedgerCalendar.addingMonths(-1, to: month) } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("前の月")
            .accessibilityIdentifier("history.previousMonth")

            Spacer(minLength: 0)
            Menu {
                ForEach(availableMonths, id: \.self) { option in
                    Button(monthTitle(option)) { month = option }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(monthTitle(month)).font(.title3.weight(.bold))
                    Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                }
                .foregroundStyle(Palette.ink)
            }
            .accessibilityLabel("表示月、\(monthTitle(month))")
            .accessibilityIdentifier("history.month")
            Spacer(minLength: 0)

            Button { month = LedgerCalendar.addingMonths(1, to: month) } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(month >= currentMonth)
            .accessibilityLabel("次の月")
            .accessibilityIdentifier("history.nextMonth")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.accent)
    }

    private var monthCalendar: some View {
        let lookup = Dictionary(uniqueKeysWithValues: days.map { (LedgerCalendar.startOfDay($0.date), $0) })
        return VStack(spacing: 7) {
            HStack(spacing: 0) {
                ForEach(Array(["日", "月", "火", "水", "木", "金", "土"].enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 6) {
                ForEach(Array(calendarDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        calendarDay(date, performance: lookup[date])
                    } else {
                        Color.clear.frame(height: 54).accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private func calendarDay(_ date: Date, performance: DailyPerformance?) -> some View {
        let isToday = LedgerCalendar.sameDay(date, Date())
        let isFuture = date > LedgerCalendar.startOfDay(Date())
        let color = performance.map { $0.profit < 0 ? Palette.negative : ($0.profit > 0 ? Palette.positive : Palette.muted) } ?? Palette.muted
        return Button {
            presentedRecord = HistoryRecordPresentation(record: performance?.record, date: date)
        } label: {
            VStack(spacing: 6) {
                Text("\(LedgerCalendar.calendar.component(.day, from: date))")
                    .font(.system(.subheadline, design: .rounded, weight: isToday ? .bold : .medium))
                    .foregroundStyle(isFuture ? Palette.muted.opacity(0.4) : Palette.ink)
                if let performance {
                    Text(calendarProfit(performance.profit))
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                } else {
                    Text(isToday ? "+" : " ")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.accent)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(performance == nil ? Color.clear : color.opacity(0.085), in: RoundedRectangle(cornerRadius: 11))
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(isToday ? Palette.accent.opacity(0.65) : Color.clear, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel("\(fullDate(date))、\(performance.map { "損益" + Money.text($0.profit, signed: true) + "、編集" } ?? (isFuture ? "未来の日付" : "記録を追加"))")
    }

    private func recordRow(_ day: DailyPerformance) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(shortDate(day.date))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Text("残高 \(Money.text(day.balance))")
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 0)
                    ProfitText(amount: day.profit, size: 21)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.muted.opacity(0.6))
                }
                if !day.record.tag.isEmpty || !day.record.note.isEmpty {
                    HStack(spacing: 8) {
                        if !day.record.tag.isEmpty {
                            Text(day.record.tag)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Palette.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Palette.accent.opacity(0.08), in: Capsule())
                                .lineLimit(1)
                        }
                        if !day.record.note.isEmpty {
                            Text(day.record.note)
                                .font(.caption)
                                .foregroundStyle(Palette.muted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(title).font(.caption2).foregroundStyle(Palette.muted)
        }
    }

    private var availableMonths: [Date] {
        Array(Set(store.data.records.map { LedgerCalendar.monthStart($0.date) } + [currentMonth, month]))
            .sorted(by: >)
    }

    private var calendarDates: [Date?] {
        let calendar = LedgerCalendar.calendar
        let offset = calendar.component(.weekday, from: month) - 1
        let count = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        let dates: [Date?] = (0..<count).map { calendar.date(byAdding: .day, value: $0, to: month) }
        return Array(repeating: nil, count: offset) + dates
    }

    private func addRecord() {
        let date = month == currentMonth ? LedgerCalendar.startOfDay(Date()) : month
        let existing = store.data.records.first { LedgerCalendar.sameDay($0.date, date) }
        presentedRecord = HistoryRecordPresentation(record: existing, date: date)
    }

    private func monthTitle(_ date: Date) -> String { formatted(date, template: "yyyy年M月") }
    private func shortDate(_ date: Date) -> String { formatted(date, template: "M月d日（E）") }
    private func fullDate(_ date: Date) -> String { formatted(date, template: "yyyy年M月d日") }

    private func formatted(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = LedgerCalendar.calendar
        formatter.timeZone = LedgerCalendar.calendar.timeZone
        formatter.dateFormat = template
        return formatter.string(from: date)
    }

    private func calendarProfit(_ amount: Int64) -> String {
        let absolute = abs(amount)
        let sign = amount > 0 ? "+" : (amount < 0 ? "−" : "")
        if absolute >= 100_000_000 { return sign + String(format: "%.1f億", Double(absolute) / 100_000_000) }
        if absolute >= 10_000 { return sign + String(format: "%.1f万", Double(absolute) / 10_000) }
        return sign + String(absolute)
    }
}

private struct HistoryRecordPresentation: Identifiable {
    let id = UUID()
    let record: TradingRecord?
    let date: Date
}
