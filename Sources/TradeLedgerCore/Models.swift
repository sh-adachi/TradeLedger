import Foundation

public enum LedgerCalendar {
    public static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        value.locale = Locale(identifier: "ja_JP")
        return value
    }

    public static func startOfDay(_ date: Date) -> Date {
        let interval = date.timeIntervalSinceReferenceDate
        // Leave invalid values untouched so validation can reject them before Calendar conversion.
        guard interval.isFinite, abs(interval) < 1_000_000_000_000 else { return date }
        return calendar.startOfDay(for: date)
    }
    public static func monthStart(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? startOfDay(date)
    }
    public static func addingMonths(_ count: Int, to date: Date) -> Date {
        calendar.date(byAdding: .month, value: count, to: date) ?? date
    }
    public static func sameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }
}

public struct TradingRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var date: Date
    public var balance: Int64
    public var deposit: Int64
    public var withdrawal: Int64
    public var note: String
    public var tag: String

    public init(id: UUID = UUID(), date: Date, balance: Int64, deposit: Int64 = 0,
                withdrawal: Int64 = 0, note: String = "", tag: String = "") {
        self.id = id
        self.date = LedgerCalendar.startOfDay(date)
        self.balance = balance
        self.deposit = deposit
        self.withdrawal = withdrawal
        self.note = note
        self.tag = tag
    }

    private enum CodingKeys: String, CodingKey { case id, date, balance, deposit, withdrawal, note, tag }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try values.decode(UUID.self, forKey: .id),
                  date: try values.decode(Date.self, forKey: .date),
                  balance: try values.decode(Int64.self, forKey: .balance),
                  deposit: try values.decode(Int64.self, forKey: .deposit),
                  withdrawal: try values.decode(Int64.self, forKey: .withdrawal),
                  note: try values.decode(String.self, forKey: .note),
                  tag: try values.decode(String.self, forKey: .tag))
    }
}

public struct LedgerData: Codable, Equatable, Sendable {
    public var initialBalance: Int64
    public var records: [TradingRecord]
    public var hasCompletedSetup: Bool

    public init(initialBalance: Int64 = 0, records: [TradingRecord] = [], hasCompletedSetup: Bool = false) {
        self.initialBalance = initialBalance
        self.records = records
        self.hasCompletedSetup = hasCompletedSetup
    }
}

public struct DailyPerformance: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let record: TradingRecord
    public let profit: Int64
    public let cumulativeProfit: Int64
    public let previousBalance: Int64
    public var date: Date { record.date }
    public var balance: Int64 { record.balance }

    public init(record: TradingRecord, profit: Int64, cumulativeProfit: Int64, previousBalance: Int64) {
        self.id = record.id
        self.record = record
        self.profit = profit
        self.cumulativeProfit = cumulativeProfit
        self.previousBalance = previousBalance
    }
}
