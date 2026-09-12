import Foundation
import Combine
import TradeLedgerCore

@MainActor
final class LedgerStore: ObservableObject {
    @Published private(set) var data: LedgerData
    @Published var errorMessage: String?
    @Published private(set) var isDemo: Bool = false

    var analytics: LedgerAnalytics { LedgerAnalytics(data: data) }

    private let fileStore: LedgerFileStore?
    private var realData: LedgerData
    private var storageNeedsRecovery = false

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let storage: LedgerFileStore?
        if arguments.contains("--uitesting") {
            storage = nil
        } else {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("TradeLedger", isDirectory: true)
            storage = LedgerFileStore(url: directory.appendingPathComponent("ledger.json"))
        }
        let initial: LedgerData
        var initialError: String?
        var needsRecovery = false
        do {
            initial = try storage?.load() ?? LedgerData()
            if storage?.didRecoverBackup == true {
                initialError = "保存データを直前のバックアップから復元しました。最後の変更が含まれていない場合があります。記録をご確認ください。"
            }
        } catch {
            // Settings must remain reachable so the user can explicitly import a backup.
            initial = LedgerData(hasCompletedSetup: true)
            needsRecovery = true
            initialError = error.localizedDescription
        }
        fileStore = storage
        realData = initial
        data = initial
        storageNeedsRecovery = needsRecovery
        errorMessage = initialError
        if arguments.contains("--demo") { loadDemo() }
    }

    @discardableResult
    func save(_ record: TradingRecord) -> Bool {
        var proposed = data
        var normalized = record
        normalized.date = LedgerCalendar.startOfDay(record.date)
        if let index = proposed.records.firstIndex(where: { $0.id == record.id }) {
            proposed.records[index] = normalized
        } else {
            proposed.records.append(normalized)
        }
        return commit(proposed)
    }

    @discardableResult
    func delete(_ record: TradingRecord) -> Bool {
        var proposed = data
        proposed.records.removeAll { $0.id == record.id }
        return commit(proposed)
    }

    @discardableResult
    func completeSetup(initialBalance: Int64) -> Bool {
        var proposed = data
        proposed.initialBalance = initialBalance
        proposed.hasCompletedSetup = true
        return commit(proposed)
    }

    @discardableResult
    func updateInitialBalance(_ amount: Int64) -> Bool {
        var proposed = data
        proposed.initialBalance = amount
        return commit(proposed)
    }

    func loadDemo() {
        if !isDemo { realData = data }
        data = DemoData.make()
        isDemo = true
    }

    func leaveDemo() {
        data = realData
        isDemo = false
    }

    @discardableResult
    func importBackup(_ bytes: Data) -> Bool {
        do {
            let proposed = try LedgerBackup.decode(bytes)
            return commit(proposed, allowsRecovery: true)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func exportBackup() throws -> URL {
        try export(try LedgerBackup.encode(data), filename: "TradeLedger-backup.json")
    }

    func exportCSV() throws -> URL {
        try export(Data(LedgerCSV.export(data).utf8), filename: "TradeLedger-records.csv")
    }

    private func commit(_ proposed: LedgerData, allowsRecovery: Bool = false) -> Bool {
        do {
            try LedgerValidation.validate(proposed)
            if !isDemo {
                guard !storageNeedsRecovery || allowsRecovery else { throw LedgerError.unreadableStore }
                try fileStore?.save(proposed)
                realData = proposed
                storageNeedsRecovery = false
            }
            data = proposed
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func export(_ bytes: Data, filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(filename)
        try bytes.write(to: url, options: .atomic)
        return url
    }
}
