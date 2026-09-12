import SwiftUI
import Charts
import TradeLedgerCore

struct AnalysisView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var year = LedgerCalendar.calendar.component(.year, from: Date())
    private var yearDate: Date { LedgerCalendar.calendar.date(from: DateComponents(year: year, month: 1, day: 1))! }
    private var days: [DailyPerformance] { store.analytics.days(inYear: yearDate) }
    private var months: [MonthResult] {
        (1...12).map { month in
            let matching = days.filter { LedgerCalendar.calendar.component(.month, from: $0.date) == month }
            return MonthResult(month: month, profit: LedgerAnalytics.profit(for: matching), count: matching.count)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("REFLECT & GROW").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(Palette.accent)
                    Text("トレードを振り返る").font(.system(size: 27, weight: .bold)).tracking(-0.7).foregroundStyle(Palette.ink)
                    Text("数字から見つける、あなたのリズム。").font(.caption).foregroundStyle(Palette.muted)
                }.padding(.vertical, 14)
                yearSelector
                yearlyCard
                if days.isEmpty {
                    Card { EmptyLedgerView(title: "この年の記録はまだありません", message: "資産額を記録すると、年間の成績を\nさまざまな角度から振り返れます。") }
                } else {
                    distributionCard
                    riskCard
                    monthlyList
                }
                Text("損益は資産額の差から入出金を除いた値です。記録のない期間の損益は、次の記録日にまとめて反映されます。プラス日率は損益0円の日を除いて計算します。")
                    .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4).padding(.horizontal, 4)
            }.padding(.horizontal, 20).padding(.bottom, 26)
        }.background(Palette.background).toolbar(.hidden, for: .navigationBar)
    }

    private var yearSelector: some View {
        HStack {
            Button { year -= 1 } label: { Image(systemName: "chevron.left").frame(width: 44, height: 40) }.accessibilityLabel("前年")
            Spacer()
            Text(String(year) + "年").font(.system(.headline, design: .rounded))
            Spacer()
            Button { year += 1 } label: { Image(systemName: "chevron.right").frame(width: 44, height: 40) }
                .disabled(year >= LedgerCalendar.calendar.component(.year, from: Date())).accessibilityLabel("翌年")
        }.foregroundStyle(Palette.ink).padding(.horizontal, 9).background(.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private var yearlyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 19) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("年間損益").font(.caption).foregroundStyle(Palette.muted)
                        ProfitText(amount: LedgerAnalytics.profit(for: days), size: 31)
                    }
                    Spacer()
                    Text("\(days.count)日記録").font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.accent)
                        .padding(9).background(Palette.mint, in: Capsule())
                }
                Chart(months) { month in
                    BarMark(x: .value("月", String(month.month)), y: .value("損益", Double(month.profit)))
                        .foregroundStyle(month.profit < 0 ? Palette.negative : Palette.accent)
                        .cornerRadius(4)
                    RuleMark(y: .value("基準", 0)).foregroundStyle(Palette.border)
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(Palette.border)
                        AxisValueLabel { if let amount = value.as(Double.self) { Text(Money.compact(Int64(amount))).font(.system(size: 9)) } }
                    }
                }
                .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 9)) } }
                .frame(height: 170).accessibilityLabel("月別損益チャート")
                HStack { Text("月別の損益"); Spacer(); Text("単位：円") }.font(.system(size: 10)).foregroundStyle(Palette.muted)
            }
        }
    }

    private var distributionCard: some View {
        let wins = days.filter { $0.profit > 0 }.count
        let losses = days.filter { $0.profit < 0 }.count
        let flat = days.count - wins - losses
        return Card {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeading(title: "プラスの日、マイナスの日", subtitle: "一日ごとの成績を見つめる")
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(wins + losses == 0 ? "—" : String(format: "%.1f", LedgerAnalytics.winRate(for: days) * 100))
                        .font(.system(size: 39, weight: .medium, design: .rounded)).foregroundStyle(Palette.ink)
                    Text("%").font(.headline).foregroundStyle(Palette.muted)
                    Spacer()
                    Text("プラス日率").font(.caption).foregroundStyle(Palette.muted)
                }
                GeometryReader { proxy in
                    HStack(spacing: 3) {
                        if wins > 0 { Capsule().fill(Palette.accent).frame(width: max(0, (proxy.size.width - 6) * CGFloat(wins) / CGFloat(days.count))) }
                        if losses > 0 { Capsule().fill(Palette.negative).frame(width: max(0, (proxy.size.width - 6) * CGFloat(losses) / CGFloat(days.count))) }
                        if flat > 0 { Capsule().fill(Palette.border) }
                    }
                }.frame(height: 10)
                HStack {
                    countLabel("プラス", count: wins, color: Palette.accent)
                    Spacer()
                    countLabel("マイナス", count: losses, color: Palette.negative)
                    Spacer()
                    countLabel("変化なし", count: flat, color: Palette.muted)
                }
            }
        }
    }

    private func countLabel(_ title: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 4) { Circle().fill(color).frame(width: 5, height: 5); Text(title) }
                .font(.system(size: 9)).foregroundStyle(Palette.muted)
            Text("\(count) 日").font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
        }
    }

    private var riskCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeading(title: "成績のポイント", subtitle: "数字を、次の判断のヒントに")
                metricRow("最大プラス", symbol: "arrow.up.right", amount: max(days.map(\.profit).max() ?? 0, 0))
                Divider().overlay(Palette.border)
                metricRow("最大マイナス", symbol: "arrow.down.right", amount: min(days.map(\.profit).min() ?? 0, 0))
                Divider().overlay(Palette.border)
                HStack {
                    Label("最大ドローダウン", systemImage: "arrow.down.to.line").font(.caption).foregroundStyle(Palette.muted)
                    Spacer()
                    Text(Money.text(LedgerAnalytics.maxDrawdown(for: days))).font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
                }
                Text("入出金を除いた累積損益の、期間内のピークからの最大下落額。")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted).lineSpacing(3)
                Divider().overlay(Palette.border)
                HStack {
                    Text("プロフィットファクター").font(.caption).foregroundStyle(Palette.muted)
                    Spacer()
                    Text(LedgerAnalytics.profitFactor(for: days).map { String(format: "%.2f", $0) } ?? "—")
                        .font(.system(size: 21, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
                }
                Text("利益の合計 ÷ 損失の合計。損失がない場合は「—」で表示。")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted)
            }
        }
    }

    private func metricRow(_ title: String, symbol: String, amount: Int64) -> some View {
        HStack {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(Palette.muted)
            Spacer()
            ProfitText(amount: amount, size: 17)
        }
    }

    private var monthlyList: some View {
        Card {
            VStack(alignment: .leading, spacing: 17) {
                SectionHeading(title: "月ごとの記録", subtitle: String(year) + " / MONTHLY REPORT")
                ForEach(months.filter { $0.count > 0 }) { result in
                    HStack {
                        Text("\(result.month)月").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink).frame(width: 42, alignment: .leading)
                        Text("\(result.count)日記録").font(.caption).foregroundStyle(Palette.muted)
                        Spacer()
                        ProfitText(amount: result.profit, size: 17)
                    }.padding(.vertical, 5)
                }
            }
        }
    }
}

private struct MonthResult: Identifiable {
    var id: Int { month }
    let month: Int
    let profit: Int64
    let count: Int
}
