import Foundation

public enum LedgerBackup {
    public static let currentVersion = 1
    public static let maximumFileBytes = 50 * 1_024 * 1_024

    private struct Envelope: Codable {
        var app: String
        var version: Int
        var data: LedgerData
    }

    public static func encode(_ data: LedgerData) throws -> Data {
        try LedgerValidation.validate(data)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let result = try encoder.encode(Envelope(app: "TradeLedger", version: currentVersion, data: data))
        guard result.count <= maximumFileBytes else { throw LedgerError.backupTooLarge }
        return result
    }

    public static func decode(_ data: Data) throws -> LedgerData {
        guard data.count <= maximumFileBytes else { throw LedgerError.backupTooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope: Envelope
        do {
            // Inspect version before decoding its payload, including future formats.
            struct Header: Decodable { let app: String; let version: Int }
            let header = try decoder.decode(Header.self, from: data)
            guard header.app == "TradeLedger" else { throw LedgerError.invalidBackup }
            guard header.version == currentVersion else { throw LedgerError.unsupportedVersion(header.version) }
            envelope = try decoder.decode(Envelope.self, from: data)
        } catch let error as LedgerError {
            throw error
        } catch {
            throw LedgerError.invalidBackup
        }
        try LedgerValidation.validate(envelope.data)
        return envelope.data
    }
}

public final class LedgerFileStore {
    public let url: URL
    public var backupURL: URL { url.appendingPathExtension("backup") }
    public private(set) var didRecoverBackup = false

    public init(url: URL) { self.url = url }

    public func load() throws -> LedgerData {
        didRecoverBackup = false
        let manager = FileManager.default
        let primaryExists = manager.fileExists(atPath: url.path)
        let backupExists = manager.fileExists(atPath: backupURL.path)
        guard primaryExists || backupExists else { return LedgerData() }
        if let data = try? readValidated(url) { return data }
        if let recovered = try? readValidated(backupURL) {
            // Never touch the valid backup during recovery.
            try write(try LedgerBackup.encode(recovered), to: url)
            didRecoverBackup = true
            return recovered
        }
        throw LedgerError.unreadableStore
    }

    public func save(_ data: LedgerData) throws {
        let encoded = try LedgerBackup.encode(data)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let previous = try? readValidated(url) {
            try write(try LedgerBackup.encode(previous), to: backupURL)
        }
        try write(encoded, to: url)
    }

    private func readValidated(_ location: URL) throws -> LedgerData {
        let attributes = try FileManager.default.attributesOfItem(atPath: location.path)
        if let size = attributes[.size] as? NSNumber, size.int64Value > Int64(LedgerBackup.maximumFileBytes) {
            throw LedgerError.backupTooLarge
        }
        return try LedgerBackup.decode(Data(contentsOf: location))
    }

    private func write(_ data: Data, to location: URL) throws {
        #if os(iOS)
        try data.write(to: location, options: [.atomic, .completeFileProtectionUnlessOpen])
        #else
        try data.write(to: location, options: .atomic)
        #endif
    }
}

public enum LedgerCSV {
    public static func export(_ data: LedgerData) -> String {
        let formatter = DateFormatter()
        formatter.calendar = LedgerCalendar.calendar
        formatter.timeZone = LedgerCalendar.calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let header = ["日付", "資産残高（円）", "入金（円）", "出金（円）", "損益（円）", "累計損益（円）", "タグ", "メモ"]
        let rows = LedgerAnalytics(data: data).days.map { day in
            [formatter.string(from: day.date), String(day.balance), String(day.record.deposit),
             String(day.record.withdrawal), String(day.profit), String(day.cumulativeProfit),
             safeText(day.record.tag), safeText(day.record.note)].map(quoted).joined(separator: ",")
        }
        return "\u{FEFF}" + ([header.map(quoted).joined(separator: ",")] + rows).joined(separator: "\r\n") + "\r\n"
    }

    private static func quoted(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func safeText(_ text: String) -> String {
        let leadingIgnored = CharacterSet.whitespacesAndNewlines.union(.controlCharacters).union(CharacterSet(charactersIn: "\u{FEFF}"))
        let trimmed = text.trimmingCharacters(in: leadingIgnored)
        if let first = trimmed.first, "=+-@".contains(first) { return "'" + text }
        if let first = text.unicodeScalars.first, CharacterSet.controlCharacters.contains(first) { return "'" + text }
        return text
    }
}
