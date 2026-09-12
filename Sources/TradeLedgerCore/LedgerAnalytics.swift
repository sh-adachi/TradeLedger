import Foundation

// Validated ledgers cannot overflow: at most 100,000 records with each input <= 10^12 yen.
// Saturation also makes the nonthrowing reporting API safe for unvalidated caller values.
private func adding(_ lhs: Int64, _ rhs: Int64) -> Int64 {
    let result = lhs.addingReportingOverflow(rhs)
    return result.overflow ? (rhs >= 0 ? .max : .min) : result.partialValue
}

private func subtracting(_ lhs: Int64, _ rhs: Int64) -> Int64 {
    let result = lhs.subtractingReportingOverflow(rhs)
    return result.overflow ? (rhs >= 0 ? .min : .max) : result.partialValue
}

public struct LedgerAnalytics {
    public let days: [DailyPerformance]
    public let currentBalance: Int64
    public let totalProfit: Int64

    public init(data: LedgerData) {
        var previous = data.initialBalance
        var cumulative: Int64 = 0
        var calculated: [DailyPerformance] = []
        calculated.reserveCapacity(data.records.count)
        for record in data.records.sorted(by: {
            $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date
        }) {
            let profit = adding(subtracting(subtracting(record.balance, previous), record.deposit), record.withdrawal)
            cumulative = adding(cumulative, profit)
            calculated.append(DailyPerformance(record: record, profit: profit, cumulativeProfit: cumulative, previousBalance: previous))
            previous = record.balance
        }
        days = calculated
        currentBalance = previous
        totalProfit = cumulative
    }

    public func days(inMonth month: Date) -> [DailyPerformance] {
        let start = LedgerCalendar.monthStart(month)
        let end = LedgerCalendar.addingMonths(1, to: start)
        return days.filter { $0.date >= start && $0.date < end }
    }

    public func days(inYear year: Date) -> [DailyPerformance] {
        let components = LedgerCalendar.calendar.dateComponents([.era, .year], from: year)
        return days.filter { LedgerCalendar.calendar.dateComponents([.era, .year], from: $0.date) == components }
    }

    public static func profit(for days: [DailyPerformance]) -> Int64 {
        days.reduce(0) { adding($0, $1.profit) }
    }

    public static func winRate(for days: [DailyPerformance]) -> Double {
        let wins = days.filter { $0.profit > 0 }.count
        let losses = days.filter { $0.profit < 0 }.count
        guard wins + losses > 0 else { return 0 }
        return Double(wins) / Double(wins + losses)
    }

    public static func maxDrawdown(for days: [DailyPerformance]) -> Int64 {
        var peak: Int64 = 0
        var cumulative: Int64 = 0
        var drawdown: Int64 = 0
        for day in days.sorted(by: { $0.date < $1.date }) {
            cumulative = adding(cumulative, day.profit)
            peak = max(peak, cumulative)
            drawdown = max(drawdown, subtracting(peak, cumulative))
        }
        return drawdown
    }

    public static func profitFactor(for days: [DailyPerformance]) -> Double? {
        let gains = days.reduce(0.0) { $0 + max(0, Double($1.profit)) }
        let losses = days.reduce(0.0) { $0 + max(0, -Double($1.profit)) }
        return losses == 0 ? nil : gains / losses
    }
}
