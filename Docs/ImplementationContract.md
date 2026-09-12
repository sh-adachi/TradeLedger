# Architecture and data contract

Native Japanese iPhone app `TradeLedger`, iOS 17+, SwiftUI / Charts. No remote dependency. Currency is whole JPY (Int64), up to 1 trillion yen per input. All days normalized with Gregorian Asia/Tokyo calendar. One closing record per date.

## Core (public in TradeLedgerCore)

- `TradingRecord: Identifiable, Codable, Equatable` with `id: UUID`, `date: Date`, `balance: Int64`, `deposit: Int64`, `withdrawal: Int64`, `note: String`, `tag: String`. Public init with default id, deposit/withdrawal=0, note/tag="".
- `LedgerData: Codable, Equatable` with `initialBalance: Int64`, `records: [TradingRecord]`, `hasCompletedSetup: Bool`. Public init defaults 0, [], false.
- `DailyPerformance: Identifiable` with `id: UUID`, `record: TradingRecord`, `profit: Int64`, `cumulativeProfit: Int64`, `previousBalance: Int64`. Computed `date: Date`, `balance: Int64`.
- `LedgerAnalytics(data: LedgerData)` with `days: [DailyPerformance]` ascending, `currentBalance: Int64`, `totalProfit: Int64`; `days(inMonth: Date)`, `days(inYear: Date)`; static `profit(for: [DailyPerformance]) -> Int64`, `winRate(for:) -> Double` (0...1; zero days excluded), `maxDrawdown(for:) -> Int64` based on cumulative adjusted P&L, `profitFactor(for:) -> Double?` (nil if no loss).
- `LedgerCalendar.calendar`, `.startOfDay(Date)`, `.monthStart(Date)`, `.addingMonths(Int,to:Date)`, `.sameDay(Date,Date)`.
- `LedgerValidation.validate(LedgerData) throws` (unique day/id, nonnegative balance/flows, bounded amounts, note/tag limits; no future date).
- `LedgerFileStore(url: URL)` with `load() throws -> LedgerData`, `save(LedgerData) throws` atomic; backup recovery from last valid version if needed. `LedgerBackup.encode(LedgerData) throws -> Data`, `.decode(Data) throws -> LedgerData`; `LedgerCSV.export(LedgerData) -> String` with spreadsheet formula injection defense.
- `DemoData.make(referenceDate: Date = Date()) -> LedgerData` for explicit opt-in demo, 3 months of realistic weekday data, no future dates.

## Application state (`TradeLedger/LedgerStore.swift`)

`@MainActor final class LedgerStore: ObservableObject` with `@Published private(set) var data: LedgerData`, `@Published var errorMessage: String?`, `@Published private(set) var isDemo: Bool`, `var analytics: LedgerAnalytics`. `init()` loads persisted data; launch arguments `--uitesting` isolates ephemeral data, `--demo` loads ephemeral demo. `func save(_ record: TradingRecord) -> Bool` inserts/replaces by id but rejects duplicate date other id, validates and persists. `func delete(_ record: TradingRecord) -> Bool`. `func completeSetup(initialBalance: Int64) -> Bool`. `func loadDemo()`, `func leaveDemo()` restore real data. `func importBackup(_ data: Data) -> Bool` validates before persist. `func exportBackup() throws -> URL`, `func exportCSV() throws -> URL`. `func updateInitialBalance(_ amount: Int64) -> Bool`. Exports temporary separate files. User data must never be overwritten by demo. Store errors surfaced in UI.

## Shared presentation (`Theme.swift`)

`Palette` static colors: background, card, ink, muted, accent (teal), positive (teal), negative (coral), border.
`Money.text(Int64, signed: Bool = false) -> String` yen formatted; `Money.compact(Int64) -> String`; `Money.parse(String) -> Int64?` supports grouping/full-width digits and bound.
`Card<Content: View>` init(@ViewBuilder content: () -> Content). `SectionHeading(title: String, subtitle: String? = nil)`.
`ProfitText(amount: Int64, size: CGFloat = 20)`.

## Screens

- `RootView` handles initial setup, demo state, global errors and four-tab navigation. `DashboardView` shows the current balance and monthly asset / adjusted profit charts. `AnalysisView` reports annual and monthly profit, positive-day ratio, profit factor and drawdown.
- `RecordEditorView(record: TradingRecord? = nil, date: Date = Date())` previews adjusted profit, validates input, saves and confirms deletion. I/O errors remain visible inside the presented form. `HistoryView` provides the month calendar and editable records. `SettingsView` edits the initial balance, exports CSV / JSON, confirms JSON replacement, and switches between real data and an in-memory demo.
- The Xcode app links the local `TradeLedgerCore` Swift Package. Test identifiers include `onboarding.initialBalance`, `onboarding.start`, `onboarding.demo`, `tab.dashboard`, `tab.history`, `tab.analysis`, `tab.settings`, `record.add`, `record.balance`, `record.deposit`, `record.withdrawal`, `record.note`, `record.save`, `record.delete`, `dashboard.currentBalance`, and `dashboard.totalProfit`.

Look: original warm off-white finance journal, rich dark ink typography, teal accent, pale mint chart, coral losses, generous rounded cards, small uppercase English eyebrow labels alongside Japanese headings. Respect dynamic type and narrow devices. Real launch starts empty onboarding; demonstration only when explicitly requested.
