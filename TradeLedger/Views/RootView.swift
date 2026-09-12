import SwiftUI
import TradeLedgerCore

private enum LedgerTab: String, CaseIterable {
    case dashboard, history, analysis, settings
    var title: String {
        switch self { case .dashboard: "ホーム"; case .history: "記録"; case .analysis: "分析"; case .settings: "設定" }
    }
    var symbol: String {
        switch self { case .dashboard: "square.grid.2x2"; case .history: "calendar"; case .analysis: "chart.bar.xaxis"; case .settings: "slider.horizontal.3" }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var tab: LedgerTab = .dashboard

    var body: some View {
        Group {
            if store.data.hasCompletedSetup {
                VStack(spacing: 0) {
                    if store.isDemo {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("デモデータを表示中").fontWeight(.medium)
                            Spacer()
                            Button("デモを終了") { store.leaveDemo() }.fontWeight(.semibold)
                                .accessibilityIdentifier("demo.exit")
                        }.font(.caption).foregroundStyle(Palette.accent).padding(.horizontal, 24).padding(.vertical, 10)
                            .background(Palette.mint)
                    }
                    NavigationStack {
                        Group {
                            switch tab {
                            case .dashboard: DashboardView()
                            case .history: HistoryView()
                            case .analysis: AnalysisView()
                            case .settings: SettingsView()
                            }
                        }
                        .background(Palette.background)
                    }
                    tabBar
                }.background(Palette.background)
            } else {
                OnboardingView()
            }
        }
        .alert("確認してください", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("閉じる", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .onChange(of: store.data.hasCompletedSetup) { _, _ in tab = .dashboard }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(LedgerTab.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    VStack(spacing: 6) {
                        Image(systemName: item.symbol).font(.system(size: 20, weight: tab == item ? .semibold : .regular))
                        Text(item.title).font(.system(size: 10, weight: tab == item ? .bold : .medium))
                    }.foregroundStyle(tab == item ? Palette.accent : Palette.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("tab.\(item.rawValue)")
                    .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }.background(.white).overlay(alignment: .top) { Rectangle().fill(Palette.border).frame(height: 1) }
    }
}

private struct OnboardingView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var initialBalance = ""
    @State private var invalid = false
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 11) {
                    BrandMark()
                    Text("TradeLedger").font(.system(size: 23, weight: .bold, design: .rounded)).tracking(-0.8)
                }.padding(.top, 26)
                VStack(alignment: .leading, spacing: 12) {
                    Text("YOUR TRADING JOURNAL").font(.system(size: 10, weight: .bold)).tracking(2.5).foregroundStyle(Palette.accent)
                    Text("日々の記録が、\n次の一歩になる。").font(.system(size: 34, weight: .bold)).tracking(-1.2).lineSpacing(6)
                    Text("資産の動きと、トレードの気づき。\nあなたのペースで、一冊に。")
                        .font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(6)
                }
                illustration
                VStack(alignment: .leading, spacing: 12) {
                    Text("はじめに、運用開始時の資産額").font(.subheadline.weight(.semibold))
                    HStack {
                        Text("¥").font(.title2).foregroundStyle(Palette.muted)
                        TextField("例：1,000,000", text: $initialBalance).keyboardType(.numberPad)
                            .font(.system(size: 26, weight: .medium, design: .rounded)).focused($focused)
                            .accessibilityIdentifier("onboarding.initialBalance")
                    }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(invalid ? Palette.negative : Palette.border))
                    Text(invalid ? "0〜1兆円の整数を入力してください。" : "最初の記録より前の資産額です。あとから変更できます。")
                        .font(.caption).foregroundStyle(invalid ? Palette.negative : Palette.muted)
                }
                VStack(spacing: 14) {
                    Button {
                        guard let amount = Money.parse(initialBalance) else { invalid = true; return }
                        focused = false
                        _ = store.completeSetup(initialBalance: amount)
                    } label: {
                        HStack { Spacer(); Text("記録をはじめる"); Image(systemName: "arrow.right"); Spacer() }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.white).padding(19)
                            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 18))
                    }.accessibilityIdentifier("onboarding.start")
                    Button("デモで使い心地をためす") { focused = false; store.loadDemo() }
                        .font(.subheadline.weight(.medium)).padding(8).accessibilityIdentifier("onboarding.demo")
                }
                Label("記録はこのiPhone内に保存されます", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(Palette.muted).frame(maxWidth: .infinity)
            }.padding(.horizontal, 28).padding(.bottom, 30)
        }.background(Palette.background).foregroundStyle(Palette.ink)
            .scrollDismissesKeyboard(.interactively)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { focused = false } } }
    }

    private var illustration: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("小さな記録、大きな気づき。").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Image(systemName: "leaf").foregroundStyle(Color(hex: 0xACE7C4))
            }
            GeometryReader { proxy in
                let values: [CGFloat] = [0.78, 0.68, 0.73, 0.45, 0.53, 0.4, 0.49, 0.24, 0.31, 0.12]
                Path { path in
                    for (index, value) in values.enumerated() {
                        let point = CGPoint(x: proxy.size.width * CGFloat(index) / 9, y: proxy.size.height * value)
                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                }.stroke(Color(hex: 0xACE7C4), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                ForEach(0..<4) { index in
                    Path { path in
                        let y = proxy.size.height * CGFloat(index + 1) / 4
                        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }.stroke(.white.opacity(0.09), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                }
            }.frame(height: 90).padding(.top, 10)
            HStack { Text("RECORD"); Spacer(); Text("REFLECT"); Spacer(); Text("GROW") }
                .font(.system(size: 8, weight: .bold)).tracking(2).foregroundStyle(.white.opacity(0.5))
        }.padding(23).background(Palette.ink, in: RoundedRectangle(cornerRadius: 24)).accessibilityHidden(true)
    }
}
