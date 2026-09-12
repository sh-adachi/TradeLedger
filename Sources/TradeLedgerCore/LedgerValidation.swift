import Foundation

public enum LedgerError: Error, LocalizedError, Equatable {
    case invalidAmount(String)
    case duplicateDate
    case duplicateID
    case futureDate
    case invalidDate
    case noteTooLong
    case tagTooLong
    case tooManyRecords
    case invalidBackup
    case unsupportedVersion(Int)
    case backupTooLarge
    case unreadableStore

    public var errorDescription: String? {
        switch self {
        case .invalidAmount(let label): return "\(label)は0〜1兆円の整数で入力してください。"
        case .duplicateDate: return "同じ日付の記録があります。既存の記録を編集してください。"
        case .duplicateID: return "記録のIDが重複しています。"
        case .futureDate: return "未来の日付は記録できません。"
        case .invalidDate: return "日付を確認してください。"
        case .noteTooLong: return "メモは2,000文字以内で入力してください。"
        case .tagTooLong: return "タグは40文字以内で入力してください。"
        case .tooManyRecords: return "記録は100,000件まで保存できます。"
        case .invalidBackup: return "バックアップの形式が正しくありません。TradeLedgerで書き出したJSONファイルを選択してください。"
        case .unsupportedVersion(let version): return "このバックアップのバージョン（\(version)）には対応していません。"
        case .backupTooLarge: return "バックアップファイルが大きすぎます（上限50MB）。"
        case .unreadableStore: return "保存データを読み込めませんでした。元のファイルは保持しています。バックアップから復元してください。"
        }
    }
}

public enum LedgerValidation {
    public static let amountLimit: Int64 = 1_000_000_000_000
    public static let maximumRecords = 100_000
    public static let noteLimit = 2_000
    public static let tagLimit = 40

    public static func validate(_ data: LedgerData) throws {
        try validateAmount(data.initialBalance, label: "開始時の資産額")
        guard data.records.count <= maximumRecords else { throw LedgerError.tooManyRecords }
        var ids = Set<UUID>()
        var dates = Set<Date>()
        let today = LedgerCalendar.startOfDay(Date())
        let earliest = LedgerCalendar.calendar.date(from: DateComponents(year: 1900, month: 1, day: 1))!
        for record in data.records {
            guard record.date.timeIntervalSinceReferenceDate.isFinite else { throw LedgerError.invalidDate }
            guard record.date >= earliest else { throw LedgerError.invalidDate }
            guard record.date < today.addingTimeInterval(86_400) else { throw LedgerError.futureDate }
            let date = LedgerCalendar.startOfDay(record.date)
            guard date <= today else { throw LedgerError.futureDate }
            guard ids.insert(record.id).inserted else { throw LedgerError.duplicateID }
            guard dates.insert(date).inserted else { throw LedgerError.duplicateDate }
            try validateAmount(record.balance, label: "資産残高")
            try validateAmount(record.deposit, label: "入金額")
            try validateAmount(record.withdrawal, label: "出金額")
            guard record.note.count <= noteLimit else { throw LedgerError.noteTooLong }
            guard record.tag.count <= tagLimit else { throw LedgerError.tagTooLong }
        }
    }

    private static func validateAmount(_ amount: Int64, label: String) throws {
        guard (0...amountLimit).contains(amount) else { throw LedgerError.invalidAmount(label) }
    }
}
