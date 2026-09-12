// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TradeLedgerCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "TradeLedgerCore", targets: ["TradeLedgerCore"])],
    targets: [
        .target(name: "TradeLedgerCore"),
        .testTarget(name: "TradeLedgerCoreTests", dependencies: ["TradeLedgerCore"])
    ]
)
