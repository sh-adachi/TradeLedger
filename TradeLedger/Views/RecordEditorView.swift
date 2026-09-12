import SwiftUI
import TradeLedgerCore

struct RecordEditorView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    private let record: TradingRecord?
    @State private var date: Date
    @State private var balance: String
    @State private var deposit: String
    @State private var withdrawal: String
    @State private var note: String
    @State private var tag: String
    @State private var validationMessage: String?
    @State private var showsDeleteConfirmation = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case balance, deposit, withdrawal, note, tag }

    init(record: TradingRecord? = nil, date: Date = Date()) {
        self.record = record
        _date = State(initialValue: record?.date ?? LedgerCalendar.startOfDay(date))
        _balance = State(initialValue: record.map { String($0.balance) } ?? "")
        _deposit = State(initialValue: record.map { $0.deposit == 0 ? "" : String($0.deposit) } ?? "")
        _withdrawal = State(initialValue: record.map { $0.withdrawal == 0 ? "" : String($0.withdrawal) } ?? "")
        _note = State(initialValue: record?.note ?? "")
        _tag = State(initialValue: record?.tag ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DAILY JOURNAL")
                            .font(.caption.weight(.semibold))
                            .tracking(2)
                            .foregroundStyle(Palette.accent)
                        Text("今日の結果を、次の一歩に。")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Text("その日の取引終了後の口座残高を記録します。")
                            .font(.subheadline)
                            .foregroundStyle(Palette.muted)
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 0) {
                            DatePicker("記録日", selection: $date, in: ...Date(), displayedComponents: .date)
                                .font(.subheadline.weight(.semibold))
                                .tint(Palette.accent)
                                .accessibilityIdentifier("record.date")
                            Divider().padding(.vertical, 12)
                            amountField("取引終了後の残高", text: $balance, placeholder: "例：1,000,000", field: .balance, identifier: "record.balance", prominent: true)
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 18) {
                            SectionHeading(title: "入出金", subtitle: "取引の損益と分けて計算します")
                            amountField("入金", text: $deposit, placeholder: "0", field: .deposit, identifier: "record.deposit")
                            Divider()
                            amountField("出金", text: $withdrawal, placeholder: "0", field: .withdrawal, identifier: "record.withdrawal")
                        }
                    }

                    if let previewProfit {
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("この日の損益")
                                            .font(.subheadline.weight(.semibold))
                                        Text("前回残高 \(Money.text(previousBalance))")
                                            .font(.caption)
                                            .foregroundStyle(Palette.muted)
                                    }
                                    Spacer(minLength: 8)
                                    ProfitText(amount: previewProfit, size: 25)
                                        .minimumScaleFactor(0.6)
                                        .lineLimit(1)
                                }
                                .accessibilityElement(children: .combine)
                                Text("残高 − 前回残高 − 入金 ＋ 出金")
                                    .font(.caption2)
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeading(title: "振り返り", subtitle: "気づきを少しだけ残しておきましょう")
                            TextField("タグ（例：日本株）", text: $tag)
                                .font(.subheadline)
                                .focused($focusedField, equals: .tag)
                                .accessibilityIdentifier("record.tag")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(["日本株", "米国株", "FX", "暗号資産"], id: \.self) { suggestion in
                                        Button { tag = tag == suggestion ? "" : suggestion } label: {
                                            Text(suggestion)
                                                .font(.caption.weight(.medium))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(tag == suggestion ? Palette.accent.opacity(0.13) : Palette.background, in: Capsule())
                                                .foregroundStyle(tag == suggestion ? Palette.accent : Palette.muted)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityAddTraits(tag == suggestion ? .isSelected : [])
                                    }
                                }
                            }
                            Divider()
                            TextField("取引のメモ、学び、次回のルール…", text: $note, axis: .vertical)
                                .lineLimit(4...8)
                                .font(.body)
                                .focused($focusedField, equals: .note)
                                .accessibilityIdentifier("record.note")
                            Text("\(note.count) / \(LedgerValidation.noteLimit)文字")
                                .font(.caption2)
                                .foregroundStyle(note.count > LedgerValidation.noteLimit ? Palette.negative : Palette.muted)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }

                    if record != nil {
                        Button(role: .destructive) { showsDeleteConfirmation = true } label: {
                            Label("この記録を削除", systemImage: "trash")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .accessibilityIdentifier("record.delete")
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.background)
            .safeAreaInset(edge: .bottom) {
                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Palette.negative)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Palette.card)
                        .accessibilityIdentifier("record.validation")
                }
            }
            .foregroundStyle(Palette.ink)
            .navigationTitle(record == nil ? "新しい記録" : "記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(Palette.muted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .tint(Palette.accent)
                        .accessibilityIdentifier("record.save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { focusedField = nil }
                        .tint(Palette.accent)
                }
            }
            .confirmationDialog("この記録を削除しますか？", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
                Button("記録を削除", role: .destructive) {
                    if let record {
                        if store.delete(record) { dismiss() }
                        else { showStoreError("記録を削除できませんでした。もう一度お試しください。") }
                    }
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("削除後は、後続の記録の損益が再計算されます。この操作は取り消せません。")
            }
        }
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .environment(\.calendar, LedgerCalendar.calendar)
        .environment(\.timeZone, LedgerCalendar.calendar.timeZone)
    }

    private func amountField(_ title: String, text: Binding<String>, placeholder: String, field: Field, identifier: String, prominent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.muted)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("¥")
                    .font(prominent ? .title2 : .title3)
                    .foregroundStyle(Palette.muted)
                TextField(placeholder, text: text)
                    .font(.system(size: prominent ? 30 : 23, weight: .semibold, design: .rounded))
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: field)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier(identifier)
            }
        }
    }

    private var previousBalance: Int64 {
        store.data.records
            .filter { $0.id != record?.id && LedgerCalendar.startOfDay($0.date) < LedgerCalendar.startOfDay(date) }
            .max { $0.date < $1.date }?.balance ?? store.data.initialBalance
    }

    private var previewProfit: Int64? {
        guard let amount = Money.parse(balance), amount >= 0,
              let depositAmount = parseFlow(deposit), depositAmount >= 0,
              let withdrawalAmount = parseFlow(withdrawal), withdrawalAmount >= 0 else { return nil }
        return amount - previousBalance - depositAmount + withdrawalAmount
    }

    private func parseFlow(_ value: String) -> Int64? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : Money.parse(value)
    }

    private func save() {
        focusedField = nil
        guard let amount = Money.parse(balance), amount >= 0,
              let depositAmount = parseFlow(deposit), depositAmount >= 0,
              let withdrawalAmount = parseFlow(withdrawal), withdrawalAmount >= 0 else {
            validationMessage = "残高・入金・出金は、0〜1兆円の整数で入力してください。"
            return
        }
        guard note.count <= LedgerValidation.noteLimit, tag.count <= LedgerValidation.tagLimit else {
            validationMessage = "メモは\(LedgerValidation.noteLimit)文字、タグは\(LedgerValidation.tagLimit)文字以内で入力してください。"
            return
        }
        let normalizedDate = LedgerCalendar.startOfDay(date)
        guard !store.data.records.contains(where: { $0.id != record?.id && LedgerCalendar.sameDay($0.date, normalizedDate) }) else {
            validationMessage = "この日付の記録はすでにあります。履歴から既存の記録を編集してください。"
            return
        }
        let updated = TradingRecord(id: record?.id ?? UUID(), date: normalizedDate, balance: amount, deposit: depositAmount, withdrawal: withdrawalAmount, note: note.trimmingCharacters(in: .whitespacesAndNewlines), tag: tag.trimmingCharacters(in: .whitespacesAndNewlines))
        validationMessage = nil
        if store.save(updated) { dismiss() }
        else { showStoreError("記録を保存できませんでした。もう一度お試しください。") }
    }

    private func showStoreError(_ fallback: String) {
        validationMessage = store.errorMessage ?? fallback
        store.errorMessage = nil
    }
}
