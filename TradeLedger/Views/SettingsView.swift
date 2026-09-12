import SwiftUI
import UniformTypeIdentifiers
import UIKit
import TradeLedgerCore

struct SettingsView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var activeSheet: SettingsPresentation?
    @State private var showsImporter = false
    @State private var pendingImport: PendingLedgerImport?
    @State private var showsImportConfirmation = false

    var body: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if store.isDemo {
                        Card {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .foregroundStyle(Palette.accent)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("デモを体験中")
                                        .font(.headline)
                                    Text("ここでの変更はデモデータに適用されます。実際の記録は別に保管されています。")
                                        .font(.subheadline)
                                        .foregroundStyle(Palette.muted)
                                }
                            }
                        }
                    }

                    settingsSection("口座", subtitle: "YOUR ACCOUNT") {
                        Button { activeSheet = .initialBalance } label: {
                            settingsRow(icon: "yensign.circle", title: "初期残高", detail: Money.text(store.data.initialBalance))
                        }
                        .accessibilityIdentifier("settings.initialBalance")
                        Text("最初の記録より前の口座残高です。損益計算の起点として使います。")
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                            .padding(.top, 10)
                    }

                    settingsSection("データ管理", subtitle: "YOUR DATA") {
                        VStack(spacing: 0) {
                            Button { exportCSV() } label: {
                                settingsRow(icon: "tablecells", title: "CSVを書き出す", detail: "表計算アプリで確認")
                            }
                            .accessibilityIdentifier("settings.exportCSV")
                            Divider().padding(.vertical, 14)
                            Button { exportBackup() } label: {
                                settingsRow(icon: "square.and.arrow.up", title: "バックアップを保存", detail: "復元用のJSONファイル")
                            }
                            .accessibilityIdentifier("settings.exportBackup")
                            Divider().padding(.vertical, 14)
                            Button { showsImporter = true } label: {
                                settingsRow(icon: "square.and.arrow.down", title: "バックアップから復元", detail: "現在の記録を置き換え")
                            }
                            .disabled(store.isDemo)
                            .opacity(store.isDemo ? 0.45 : 1)
                            .accessibilityIdentifier("settings.importBackup")
                        }
                        Text(store.isDemo ? "復元するには、デモを終了してください。書き出しには現在のデモデータが含まれます。" : "記録はこの端末に保存されます。機種変更やアプリの削除に備えて、定期的なバックアップをおすすめします。")
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                            .padding(.top, 16)
                    }

                    settingsSection("使い方", subtitle: "MAKE IT A HABIT") {
                        VStack(alignment: .leading, spacing: 15) {
                            helpStep("1", title: "取引後の残高を記録", detail: "1日につき1件、取引終了後の口座残高を入力します。")
                            helpStep("2", title: "入出金を入力", detail: "資金の移動を差し引き、取引による損益を計算します。")
                            helpStep("3", title: "記録を振り返る", detail: "カレンダーや分析で、自分の取引の傾向を確認します。")
                        }
                    }

                    settingsSection("デモ", subtitle: "TAKE A LOOK") {
                        Button {
                            if store.isDemo { store.leaveDemo() } else { store.loadDemo() }
                        } label: {
                            settingsRow(icon: store.isDemo ? "arrow.uturn.backward" : "sparkles", title: store.isDemo ? "自分の記録に戻る" : "サンプルデータを体験", detail: store.isDemo ? "デモを終了します" : "約3か月分の記録を表示")
                        }
                        .accessibilityIdentifier(store.isDemo ? "settings.leaveDemo" : "settings.loadDemo")
                        Text("デモの開始・終了で、自分の記録が消えることはありません。")
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                            .padding(.top, 12)
                    }

                    settingsSection("プライバシー", subtitle: "PRIVATE BY DESIGN") {
                        Label("アカウント登録は不要です", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.subheadline.weight(.medium))
                        Text("TradeLedgerは、記録をアプリから外部サーバーへ送信しません。銀行・証券口座への接続、広告、行動追跡の機能はありません。ファイルを書き出すときだけ、選んだ保存先や共有先にデータを渡します。端末のバックアップはiOSの設定に従います。")
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                            .lineSpacing(4)
                            .padding(.top, 12)
                    }

                    VStack(spacing: 7) {
                        Text("TradeLedger")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Text("取引を記録し、自分のペースを知る。")
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                        Text("バージョン \(appVersion)")
                            .font(.caption2)
                            .foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .padding(20)
                .padding(.bottom, 12)
            }
            .background(Palette.background)
            .foregroundStyle(Palette.ink)
            .navigationTitle("設定")
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .initialBalance:
                    InitialBalanceEditorView().environmentObject(store)
                case .export(let url):
                    LedgerShareSheet(url: url)
                        .presentationDetents([.medium, .large])
                }
            }
            .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.json], allowsMultipleSelection: false, onCompletion: readImport)
            .alert("バックアップを復元しますか？", isPresented: $showsImportConfirmation) {
                Button("キャンセル", role: .cancel) { pendingImport = nil }
                Button("置き換えて復元", role: .destructive) {
                    if let pendingImport { _ = store.importBackup(pendingImport.bytes) }
                    pendingImport = nil
                }
            } message: {
                if let pendingImport {
                    Text("\(pendingImport.recordCount)件の記録・初期残高\(Money.text(pendingImport.initialBalance))を読み込みます。現在の\(store.data.records.count)件の記録は置き換わります。必要な記録は先にバックアップしてください。")
                }
            }
        }
    }

    private func settingsSection<Content: View>(_ title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: title, subtitle: subtitle)
            Card {
                VStack(alignment: .leading, spacing: 0, content: content)
            }
            .buttonStyle(.plain)
        }
    }

    private func settingsRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(width: 36, height: 40)
                .background(Palette.accent.opacity(0.075), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.muted.opacity(0.6))
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func helpStep(_ number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.accent)
                .frame(width: 24, height: 24)
                .background(Palette.accent.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func exportCSV() {
        do { activeSheet = .export(try store.exportCSV()) }
        catch { store.errorMessage = "CSVを書き出せませんでした。\(error.localizedDescription)" }
    }

    private func exportBackup() {
        do { activeSheet = .export(try store.exportBackup()) }
        catch { store.errorMessage = "バックアップを保存できませんでした。\(error.localizedDescription)" }
    }

    private func readImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            if let fileSize, fileSize > LedgerBackup.maximumFileBytes { throw LedgerError.backupTooLarge }
            let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
            let backup = try LedgerBackup.decode(bytes)
            try LedgerValidation.validate(backup)
            pendingImport = PendingLedgerImport(bytes: bytes, recordCount: backup.records.count, initialBalance: backup.initialBalance)
            showsImportConfirmation = true
        } catch {
            store.errorMessage = "バックアップを読み込めませんでした。\(error.localizedDescription)"
        }
    }
}

private enum SettingsPresentation: Identifiable {
    case initialBalance
    case export(URL)

    var id: String {
        switch self {
        case .initialBalance: return "initialBalance"
        case .export(let url): return url.absoluteString
        }
    }
}

private struct PendingLedgerImport {
    let bytes: Data
    let recordCount: Int
    let initialBalance: Int64
}

private struct LedgerShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}

private struct InitialBalanceEditorView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var validationMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("損益計算のスタート地点")
                        .font(.title2.weight(.semibold))
                    Text("最初の記録より前の口座残高を入力してください。変更すると、損益が再計算されます。")
                        .font(.subheadline)
                        .foregroundStyle(Palette.muted)
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("初期残高")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Palette.muted)
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("¥").font(.title2).foregroundStyle(Palette.muted)
                                TextField("0", text: $amount)
                                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                                    .keyboardType(.numberPad)
                                    .focused($isFocused)
                                    .accessibilityIdentifier("settings.initialBalance.value")
                            }
                        }
                    }
                    if let validationMessage {
                        Text(validationMessage)
                            .font(.subheadline)
                            .foregroundStyle(Palette.negative)
                    }
                }
                .padding(20)
            }
            .background(Palette.background)
            .foregroundStyle(Palette.ink)
            .navigationTitle("初期残高")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }.foregroundStyle(Palette.muted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard let parsed = Money.parse(amount), parsed >= 0 else {
                            validationMessage = "0〜1兆円の整数で入力してください。"
                            return
                        }
                        if store.updateInitialBalance(parsed) { dismiss() }
                        else {
                            validationMessage = store.errorMessage ?? "初期残高を保存できませんでした。もう一度お試しください。"
                            store.errorMessage = nil
                            isFocused = false
                        }
                    }
                    .fontWeight(.semibold)
                    .tint(Palette.accent)
                    .accessibilityIdentifier("settings.initialBalance.save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { isFocused = false }.tint(Palette.accent)
                }
            }
            .onAppear { amount = String(store.data.initialBalance) }
        }
    }
}
