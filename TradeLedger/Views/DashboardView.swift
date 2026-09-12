import SwiftUI
import Charts
import TradeLedgerCore

struct DashboardView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var month = LedgerCalendar.monthStart(Date())
    @State private var showingEditor = false
    @State private var chartMode = 0

    private var days: [DailyPerformance] { store.analytics.days(inMonth: month) }
    private var monthProfit: Int64 { LedgerAnalytics.profit(for: days) }
    private var todayRecord: TradingRecord? {
        store.data.records.first { LedgerCalendar.sameDay($0.date, Date()) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                balanceCard
                chartCard
                monthStats
                recentRecords
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                    Text("あなたの記録を、このiPhoneに。")
                }.font(.system(size: 10)).foregroundStyle(Palette.muted).padding(.bottom, 5)
            }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Palette.background)
        .sheet(isPresented: $showingEditor) { RecordEditorView(record: todayRecord) }
    }

    private var header: some View {
        HStack(spacing: 10) {
            BrandMark(size: 37)
            VStack(alignment: .leading, spacing: 3) {
                Text("TradeLedger").font(.system(size: 23, weight: .bold, design: .rounded)).tracking(-0.9)
                    .foregroundStyle(Palette.ink)
                Text("日々を記録して、次の一歩へ。").font(.system(size: 10)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 5)
            Button { showingEditor = true } label: {
                Image(systemName: "plus").font(.system(size: 18, weight: .medium)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(Palette.ink, in: Circle())
            }.accessibilityLabel(todayRecord == nil ? "今日の記録を追加" : "今日の記録を編集")
                .accessibilityIdentifier("record.add")
        }.padding(.vertical, 10)
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("PORTFOLIO").font(.system(size: 10, weight: .semibold)).tracking(2.5)
                Spacer()
                Circle().fill(Color(hex: 0xACE7C4)).frame(width: 5, height: 5)
                Text(store.isDemo ? "DEMO" : "PRIVATE").font(.system(size: 9, weight: .medium)).tracking(1.2)
            }.foregroundStyle(.white.opacity(0.6))
            VStack(alignment: .leading, spacing: 7) {
                Text("総資産").font(.caption).foregroundStyle(.white.opacity(0.7))
                Text(Money.text(store.analytics.currentBalance))
                    .font(.system(size: 37, weight: .medium, design: .rounded)).tracking(-1.3).monospacedDigit()
                    .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.45)
                    .accessibilityIdentifier("dashboard.currentBalance")
            }
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: store.analytics.totalProfit < 0 ? "arrow.down.right" : "arrow.up.right")
                    Text(Money.text(store.analytics.totalProfit, signed: true)).monospacedDigit()
                        .accessibilityIdentifier("dashboard.totalProfit")
                }.font(.system(size: 12, weight: .semibold)).foregroundStyle(store.analytics.totalProfit < 0 ? Color(hex: 0xFFB7AD) : Color(hex: 0xBCEFD2))
                    .padding(.horizontal, 10).padding(.vertical, 7).background(.white.opacity(0.08), in: Capsule())
                Text("累計損益").font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
                Spacer(minLength: 0)
            }
            Rectangle().fill(.white.opacity(0.1)).frame(height: 1)
            HStack {
                Text(store.analytics.days.last.map { "最終記録  " + DisplayDate.string($0.date, "M月d日") } ?? "運用開始時の資産")
                Spacer()
                Text("JPY / 円")
            }.font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
        }.padding(24).background {
            ZStack(alignment: .topTrailing) {
                Palette.ink
                Circle().stroke(.white.opacity(0.035), lineWidth: 26).frame(width: 195, height: 195).offset(x: 70, y: -65)
                Circle().stroke(.white.opacity(0.03), lineWidth: 1).frame(width: 255, height: 255).offset(x: 100, y: -95)
            }.clipShape(RoundedRectangle(cornerRadius: 27))
        }
    }

    private var chartCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    SectionHeading(title: "資産のあしあと", subtitle: "PERFORMANCE")
                    Spacer()
                    HStack(spacing: 0) {
                        chartButton("資産", mode: 0)
                        chartButton("損益", mode: 1)
                    }.padding(3).background(Palette.background, in: Capsule())
                }
                MonthNavigator(month: $month)
                if days.isEmpty {
                    EmptyLedgerView(title: "この月の記録はまだありません", message: "右上の＋から資産額を記録しましょう。")
                } else {
                    performanceChart
                    HStack {
                        Circle().fill(Palette.accent).frame(width: 5, height: 5)
                        Text(chartMode == 0 ? "記録日の資産額" : "入出金を除いた累積損益")
                        Spacer()
                        Text("\(days.count)日記録")
                    }.font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
            }
        }
    }

    private func chartButton(_ title: String, mode: Int) -> some View {
        Button { chartMode = mode } label: {
            Text(title).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(chartMode == mode ? Palette.accent : Palette.muted)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(chartMode == mode ? .white : .clear, in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(chartMode == mode ? .isSelected : [])
    }

    private var chartValues: [ChartPoint] {
        guard let first = days.first else { return [] }
        let offset = first.cumulativeProfit - first.profit
        var result = [ChartPoint(date: first.date.addingTimeInterval(-1), amount: chartMode == 0 ? first.previousBalance : 0)]
        result.append(contentsOf: days.map { ChartPoint(date: $0.date, amount: chartMode == 0 ? $0.balance : $0.cumulativeProfit - offset) })
        return result
    }

    private var chartDomain: ClosedRange<Double> {
        let values = chartValues.map { Double($0.amount) }
        let low = values.min() ?? 0
        let high = values.max() ?? 0
        let padding = max((high - low) * 0.2, 1_000)
        return (low - padding)...(high + padding)
    }

    private var performanceChart: some View {
        Chart(chartValues) { point in
            AreaMark(x: .value("日付", point.date), yStart: .value("基準", chartDomain.lowerBound), yEnd: .value("金額", Double(point.amount)))
                .foregroundStyle(LinearGradient(colors: [Palette.accent.opacity(0.2), Palette.accent.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.linear)
            LineMark(x: .value("日付", point.date), y: .value("金額", Double(point.amount)))
                .foregroundStyle(Palette.accent).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.linear)
        }
        .chartYScale(domain: chartDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, days.count / 4))) { value in
                AxisValueLabel { if let date = value.as(Date.self) { Text(DisplayDate.string(date, "M/d")).font(.system(size: 9)) } }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(Palette.border)
                AxisValueLabel { if let number = value.as(Double.self) { Text(Money.compact(Int64(number))).font(.system(size: 9)) } }
            }
        }.frame(height: 175)
        .accessibilityLabel(chartMode == 0 ? "月間資産推移" : "月間累積損益")
    }

    private var monthStats: some View {
        HStack(spacing: 12) {
            Card {
                VStack(alignment: .leading, spacing: 11) {
                    Label("月間損益", systemImage: "arrow.up.arrow.down").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    ProfitText(amount: monthProfit, size: 23)
                    Text("入出金を除く").font(.system(size: 9)).foregroundStyle(Palette.muted)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 11) {
                    Label("プラス日率", systemImage: "scope").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    Text(days.filter { $0.profit != 0 }.isEmpty ? "—" : String(format: "%.0f%%", LedgerAnalytics.winRate(for: days) * 100))
                        .font(.system(size: 23, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink).monospacedDigit()
                    Text("プラス・マイナス日の比率").font(.system(size: 9)).foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
    }

    private var recentRecords: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    SectionHeading(title: "最近の記録", subtitle: "日々の積み重ね")
                    Spacer()
                    Image(systemName: "text.book.closed").foregroundStyle(Palette.accent)
                }
                if store.analytics.days.isEmpty {
                    Text("今日の取引が終わったら、最初の記録を。")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    Button { showingEditor = true } label: {
                        Label("今日を記録する", systemImage: "plus").font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(15).background(Palette.mint, in: RoundedRectangle(cornerRadius: 13))
                    }
                } else {
                    ForEach(Array(store.analytics.days.suffix(3).reversed())) { day in
                        HStack(spacing: 12) {
                            VStack(spacing: 2) {
                                Text(DisplayDate.string(day.date, "dd")).font(.system(size: 20, weight: .semibold, design: .rounded))
                                Text(DisplayDate.string(day.date, "E")).font(.system(size: 9))
                            }.foregroundStyle(Palette.muted).frame(width: 40, height: 49)
                                .background(Palette.background, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(day.record.tag.isEmpty ? "トレード記録" : day.record.tag).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink)
                                Text(day.record.note.isEmpty ? "資産 " + Money.text(day.balance) : day.record.note)
                                    .font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
                            }
                            Spacer(minLength: 3)
                            ProfitText(amount: day.profit, size: 14)
                        }
                    }
                }
            }
        }
    }
}

private struct ChartPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let amount: Int64
}
