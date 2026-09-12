import SwiftUI

@main
struct TradeLedgerApp: App {
    @StateObject private var store = LedgerStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .tint(Palette.accent)
        }
    }
}
