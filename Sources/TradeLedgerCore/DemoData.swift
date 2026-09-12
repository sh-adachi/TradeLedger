import Foundation

public enum DemoData {
    public static func make(referenceDate: Date = Date()) -> LedgerData {
        let today = min(LedgerCalendar.startOfDay(referenceDate), LedgerCalendar.startOfDay(Date()))
        let start = LedgerCalendar.addingMonths(-2, to: LedgerCalendar.monthStart(today))
        var date = start
        var balance: Int64 = 1_000_000
        var records: [TradingRecord] = []
        let profits: [Int64] = [4_800, 2_100, -3_600, 7_200, 1_400, -1_900, 5_300, 3_800, -2_400, 6_100, 900, -4_200, 8_600, 2_700, 0]
        let notes = ["計画どおりに利確。ルールを守れた。", "エントリーを厳選して落ち着いて取引。", "損切りラインを優先。次の機会を待つ。", "相場の流れを確認してから判断。", "取引を振り返り、次回の改善点を記録。"]
        var index = 0
        while date <= today {
            let weekday = LedgerCalendar.calendar.component(.weekday, from: date)
            if weekday != 1 && weekday != 7 {
                let profit = profits[index % profits.count]
                let deposit: Int64 = index == 20 ? 100_000 : 0
                let withdrawal: Int64 = index == 38 ? 30_000 : 0
                balance += profit + deposit - withdrawal
                records.append(TradingRecord(date: date, balance: balance, deposit: deposit, withdrawal: withdrawal,
                                             note: index % 3 == 0 ? notes[index % notes.count] : "",
                                             tag: index % 4 == 0 ? "日本株" : ""))
                index += 1
            }
            guard let next = LedgerCalendar.calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return LedgerData(initialBalance: 1_000_000, records: records, hasCompletedSetup: true)
    }
}
