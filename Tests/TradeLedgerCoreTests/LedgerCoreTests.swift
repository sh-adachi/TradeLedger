import XCTest
@testable import TradeLedgerCore

final class LedgerCoreTests: XCTestCase {
    private func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = LedgerCalendar.calendar
        formatter.timeZone = LedgerCalendar.calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text + (text.count == 10 ? " 00:00" : ""))!
    }

    private var example: LedgerData {
        LedgerData(initialBalance: 100_000, records: [
            TradingRecord(date: date("2024-01-30"), balance: 112_000, deposit: 10_000),
            TradingRecord(date: date("2024-01-31"), balance: 104_000, withdrawal: 5_000),
            TradingRecord(date: date("2024-02-01"), balance: 108_000),
            TradingRecord(date: date("2024-02-02"), balance: 108_000)
        ], hasCompletedSetup: true)
    }

    func testFlowsAreExcludedFromProfitAndRecordsAreSorted() throws {
        var input = example
        input.records.reverse()
        try LedgerValidation.validate(input)
        let analytics = LedgerAnalytics(data: input)
        XCTAssertEqual(analytics.days.map(\.profit), [2_000, -3_000, 4_000, 0])
        XCTAssertEqual(analytics.days.map(\.cumulativeProfit), [2_000, -1_000, 3_000, 3_000])
        XCTAssertEqual(analytics.days.map(\.previousBalance), [100_000, 112_000, 104_000, 108_000])
        XCTAssertEqual(analytics.totalProfit, 3_000)
        XCTAssertEqual(analytics.currentBalance, 108_000)
        XCTAssertEqual(LedgerAnalytics.winRate(for: analytics.days), 2.0 / 3.0, accuracy: 0.000001)
        XCTAssertEqual(LedgerAnalytics.profitFactor(for: analytics.days), 2)
        XCTAssertEqual(LedgerAnalytics.maxDrawdown(for: analytics.days), 3_000)
    }

    func testMonthMetricsIncludePreviousMonthsClosingBalance() {
        let analytics = LedgerAnalytics(data: example)
        let january = analytics.days(inMonth: date("2024-01-15"))
        let february = analytics.days(inMonth: date("2024-02-29"))
        XCTAssertEqual(LedgerAnalytics.profit(for: january), -1_000)
        XCTAssertEqual(LedgerAnalytics.profit(for: february), 4_000)
        XCTAssertEqual(february.first?.previousBalance, 104_000)
        XCTAssertEqual(analytics.days(inYear: date("2024-09-01")).count, 4)
        XCTAssertTrue(analytics.days(inYear: date("2023-09-01")).isEmpty)
    }

    func testDrawdownStartsAtPeriodOpeningEquityAndIgnoresFlows() {
        let input = LedgerData(initialBalance: 100, records: [
            TradingRecord(date: date("2024-01-01"), balance: 190, deposit: 100),
            TradingRecord(date: date("2024-01-02"), balance: 205),
            TradingRecord(date: date("2024-01-03"), balance: 200),
            TradingRecord(date: date("2024-01-04"), balance: 208)
        ])
        let days = LedgerAnalytics(data: input).days
        XCTAssertEqual(days.map(\.profit), [-10, 15, -5, 8])
        XCTAssertEqual(LedgerAnalytics.maxDrawdown(for: days), 10)
        XCTAssertEqual(LedgerAnalytics.maxDrawdown(for: Array(days.suffix(2))), 5)
        XCTAssertEqual(LedgerAnalytics.maxDrawdown(for: days.reversed()), 10)
    }

    func testEmptyAndZeroLedgersHaveDefinedMetrics() {
        let analytics = LedgerAnalytics(data: LedgerData(initialBalance: 345_678))
        XCTAssertEqual(analytics.currentBalance, 345_678)
        XCTAssertEqual(analytics.totalProfit, 0)
        XCTAssertEqual(LedgerAnalytics.winRate(for: []), 0)
        XCTAssertEqual(LedgerAnalytics.maxDrawdown(for: []), 0)
        XCTAssertNil(LedgerAnalytics.profitFactor(for: []))
        let flat = LedgerAnalytics(data: LedgerData(records: [TradingRecord(date: date("2024-01-01"), balance: 0)])).days
        XCTAssertEqual(LedgerAnalytics.winRate(for: flat), 0)
        XCTAssertNil(LedgerAnalytics.profitFactor(for: flat))
    }

    func testDepositAndWithdrawalAloneDoNotChangePerformance() {
        let input = LedgerData(initialBalance: 100, records: [
            TradingRecord(date: date("2024-01-01"), balance: 200, deposit: 100),
            TradingRecord(date: date("2024-01-02"), balance: 50, withdrawal: 150)
        ])
        let analytics = LedgerAnalytics(data: input)
        XCTAssertEqual(analytics.totalProfit, 0)
        XCTAssertEqual(LedgerAnalytics.maxDrawdown(for: analytics.days), 0)
    }

    func testHistoricalEditAndDeletionRecalculateFollowingDay() {
        var input = example
        input.records[0].balance = 110_000
        XCTAssertEqual(LedgerAnalytics(data: input).days.map(\.profit), [0, -1_000, 4_000, 0])
        input.records.remove(at: 0)
        XCTAssertEqual(LedgerAnalytics(data: input).days.map(\.profit), [9_000, 4_000, 0])
    }

    func testUpperBoundArithmeticRemainsExact() throws {
        let limit = LedgerValidation.amountLimit
        let input = LedgerData(initialBalance: limit, records: [
            TradingRecord(date: date("2024-01-01"), balance: 0, deposit: limit),
            TradingRecord(date: date("2024-01-02"), balance: limit, withdrawal: limit)
        ])
        try LedgerValidation.validate(input)
        let analytics = LedgerAnalytics(data: input)
        XCTAssertEqual(analytics.days.map(\.profit), [-2 * limit, 2 * limit])
        XCTAssertEqual(analytics.totalProfit, 0)
        XCTAssertEqual(LedgerAnalytics.maxDrawdown(for: analytics.days), 2 * limit)
    }

    func testValidationRejectsNegativeAndExcessiveAmounts() {
        XCTAssertThrowsError(try LedgerValidation.validate(LedgerData(initialBalance: -1)))
        XCTAssertThrowsError(try LedgerValidation.validate(LedgerData(initialBalance: LedgerValidation.amountLimit + 1)))
        for keyPath in [\TradingRecord.balance, \.deposit, \.withdrawal] {
            var record = example.records[0]
            record[keyPath: keyPath] = -1
            XCTAssertThrowsError(try LedgerValidation.validate(LedgerData(records: [record])))
            record[keyPath: keyPath] = Int64.max
            XCTAssertThrowsError(try LedgerValidation.validate(LedgerData(records: [record])))
        }
    }

    func testValidationRejectsDuplicateDatesAndIDs() {
        var input = example
        input.records.append(TradingRecord(date: date("2024-01-30 23:59"), balance: 0))
        XCTAssertThrowsError(try LedgerValidation.validate(input)) { XCTAssertEqual($0 as? LedgerError, .duplicateDate) }
        input = example
        input.records[1].id = input.records[0].id
        XCTAssertThrowsError(try LedgerValidation.validate(input)) { XCTAssertEqual($0 as? LedgerError, .duplicateID) }
    }

    func testValidationRejectsFutureAndOversizedText() {
        var input = example
        input.records[0].date = LedgerCalendar.calendar.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertThrowsError(try LedgerValidation.validate(input)) { XCTAssertEqual($0 as? LedgerError, .futureDate) }
        input = example
        input.records[0].note = String(repeating: "あ", count: LedgerValidation.noteLimit + 1)
        XCTAssertThrowsError(try LedgerValidation.validate(input)) { XCTAssertEqual($0 as? LedgerError, .noteTooLong) }
        input = example
        input.records[0].tag = String(repeating: "a", count: LedgerValidation.tagLimit + 1)
        XCTAssertThrowsError(try LedgerValidation.validate(input)) { XCTAssertEqual($0 as? LedgerError, .tagTooLong) }
    }

    func testCalendarAlwaysUsesTokyoDayBoundaries() {
        let iso = ISO8601DateFormatter()
        let utcEvening = iso.date(from: "2024-01-31T16:30:00Z")!
        XCTAssertEqual(LedgerCalendar.startOfDay(utcEvening), date("2024-02-01"))
        XCTAssertEqual(LedgerCalendar.monthStart(utcEvening), date("2024-02-01"))
        XCTAssertTrue(LedgerCalendar.sameDay(utcEvening, date("2024-02-01 23:00")))
        XCTAssertEqual(LedgerCalendar.addingMonths(1, to: date("2024-02-01")), date("2024-03-01"))
    }

    func testValidationRejectsNonfiniteAndExtremeDatesWithoutCalendarCrashes() {
        for interval in [Double.nan, Double.infinity, -Double.infinity, -1e100, 1e100] {
            let record = TradingRecord(date: Date(timeIntervalSinceReferenceDate: interval), balance: 0)
            XCTAssertThrowsError(try LedgerValidation.validate(LedgerData(records: [record])))
        }
        XCTAssertThrowsError(try LedgerValidation.validate(LedgerData(records: [
            TradingRecord(date: date("1899-12-31"), balance: 0)
        ])))
    }

    func testRecordLimitRejectsBeforeProcessingOversizedImports() {
        let record = TradingRecord(date: date("2024-01-01"), balance: 0)
        let oversized = LedgerData(records: Array(repeating: record, count: LedgerValidation.maximumRecords + 1))
        XCTAssertThrowsError(try LedgerValidation.validate(oversized)) { XCTAssertEqual($0 as? LedgerError, .tooManyRecords) }
    }

    func testVersionedBackupRoundTripPreservesJapaneseAndIDs() throws {
        var input = example
        input.records[0].note = "振り返り\n利益確定 \"計画どおり\" 🌱"
        input.records[0].tag = "日本株"
        let encoded = try LedgerBackup.encode(input)
        XCTAssertEqual(try LedgerBackup.decode(encoded), input)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["app"] as? String, "TradeLedger")
        XCTAssertEqual(object["version"] as? Int, 1)
    }

    func testBackupRejectsUnknownVersionMalformedAndInvalidData() throws {
        XCTAssertThrowsError(try LedgerBackup.decode(Data("not json".utf8)))
        XCTAssertThrowsError(try LedgerBackup.decode(Data(#"{"app":"TradeLedger","version":99}"#.utf8))) {
            XCTAssertEqual($0 as? LedgerError, .unsupportedVersion(99))
        }
        let valid = try LedgerBackup.encode(example)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: valid) as? [String: Any])
        var payload = try XCTUnwrap(object["data"] as? [String: Any])
        payload["initialBalance"] = -1
        object["data"] = payload
        XCTAssertThrowsError(try LedgerBackup.decode(JSONSerialization.data(withJSONObject: object)))
        object["app"] = "AnotherApp"
        XCTAssertThrowsError(try LedgerBackup.decode(JSONSerialization.data(withJSONObject: object))) {
            XCTAssertEqual($0 as? LedgerError, .invalidBackup)
        }
    }

    func testCSVPreservesMultilineQuotedTextAndNeutralizesFormulaPrefixes() {
        let dangerous = ["=HYPERLINK(\"https://example.com\")", "+SUM(1,2)", "-1+2", "@SUM(A1)", "  =1+1", "\t=1+1", "\rplain", "\u{FEFF}=1+1"]
        for text in dangerous {
            let input = LedgerData(records: [TradingRecord(date: date("2024-01-01"), balance: 0, note: text, tag: text)])
            let exported = LedgerCSV.export(input)
            XCTAssertTrue(exported.hasPrefix("\u{FEFF}"))
            XCTAssertTrue(exported.contains("\"'" + text.replacingOccurrences(of: "\"", with: "\"\"")))
        }
        let input = LedgerData(records: [TradingRecord(date: date("2024-01-01"), balance: 0, note: "通常のメモ,\n\"継続\"")])
        XCTAssertTrue(LedgerCSV.export(input).contains("\"通常のメモ,\n\"\"継続\"\"\""))
        XCTAssertTrue(LedgerCSV.export(example).contains("\"-3000\""))
    }

    func testFileStoreRoundTripAndBackupRecovery() throws {
        let original = example
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LedgerFileStore(url: directory.appendingPathComponent("ledger.json"))
        XCTAssertEqual(try store.load(), LedgerData())
        try store.save(original)
        XCTAssertEqual(try store.load(), original)
        var next = original
        next.initialBalance = 90_000
        try store.save(next)
        XCTAssertEqual(try store.load(), next)
        XCTAssertEqual(try LedgerBackup.decode(Data(contentsOf: store.backupURL)), original)
        try Data("truncated".utf8).write(to: store.url)
        XCTAssertEqual(try store.load(), original)
        XCTAssertTrue(store.didRecoverBackup)
        XCTAssertEqual(try LedgerBackup.decode(Data(contentsOf: store.url)), original)
        XCTAssertEqual(try store.load(), original)
        XCTAssertFalse(store.didRecoverBackup)
    }

    func testMissingPrimaryRecoversBackupAndInvalidSaveKeepsPreviousData() throws {
        let original = example
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LedgerFileStore(url: directory.appendingPathComponent("ledger.json"))
        try store.save(original)
        try store.save(original)
        try FileManager.default.removeItem(at: store.url)
        XCTAssertEqual(try store.load(), original)
        XCTAssertThrowsError(try store.save(LedgerData(initialBalance: -1)))
        XCTAssertEqual(try store.load(), original)
    }

    func testUnrecoverableCorruptionIsReportedAndFilesAreRetained() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = LedgerFileStore(url: directory.appendingPathComponent("ledger.json"))
        let corrupted = Data("broken".utf8)
        try corrupted.write(to: store.url)
        XCTAssertThrowsError(try store.load()) { XCTAssertEqual($0 as? LedgerError, .unreadableStore) }
        XCTAssertEqual(try Data(contentsOf: store.url), corrupted)
    }

    func testFailedBackupWriteLeavesPrimaryUnchanged() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LedgerFileStore(url: directory.appendingPathComponent("ledger.json"))
        let original = example
        try store.save(original)
        // A directory at the backup path simulates a write failure independently of user permissions.
        try FileManager.default.createDirectory(at: store.backupURL, withIntermediateDirectories: true)
        var changed = original
        changed.initialBalance = 90_000
        XCTAssertThrowsError(try store.save(changed))
        XCTAssertEqual(try store.load(), original)
    }

    func testDemoIsValidWeekdayOnlyThreeMonthData() throws {
        let reference = date("2024-03-15")
        let demo = DemoData.make(referenceDate: reference)
        try LedgerValidation.validate(demo)
        XCTAssertTrue(demo.hasCompletedSetup)
        XCTAssertGreaterThan(demo.records.count, 40)
        XCTAssertEqual(LedgerCalendar.monthStart(try XCTUnwrap(demo.records.first).date), date("2024-01-01"))
        XCTAssertTrue(demo.records.allSatisfy { $0.date <= reference })
        XCTAssertTrue(demo.records.allSatisfy { ![1, 7].contains(LedgerCalendar.calendar.component(.weekday, from: $0.date)) })
        XCTAssertTrue(demo.records.contains { $0.deposit > 0 })
        XCTAssertTrue(demo.records.contains { $0.withdrawal > 0 })
    }
}
