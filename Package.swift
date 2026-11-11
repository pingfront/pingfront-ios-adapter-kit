// swift-tools-version: 6.2
import PackageDescription

/// The same upcoming language features as the pingfront SDK (pingfront-ios).
let upcoming: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),  // SE-0461
    .enableUpcomingFeature("InferIsolatedConformances"),  // SE-0470
    .enableUpcomingFeature("ExistentialAny"),  // SE-0335
    .enableUpcomingFeature("MemberImportVisibility"),  // SE-0444
    .enableUpcomingFeature("InternalImportsByDefault"),  // SE-0409
]

/// What the pingfront vendor adapters share: slot rules, entitlement mapping, the host seam, presentation.
///
/// Each adapter is its own package (RevenueCat, Superwall, Adapty) so an app fetches only the vendor it uses.
/// This package depends on nothing but the pingfront SDK. Apps don't link it directly.
let package = Package(
    name: "PingFrontAdapterKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PingFrontAdapterKit", targets: ["PingFrontAdapterKit"]),
        // Test doubles (fake host, no-op sleep, settle) for the adapters' tests. Never linked into an app.
        .library(name: "PingFrontAdapterTestSupport", targets: ["PingFrontAdapterTestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pingfront/pingfront-ios", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "PingFrontAdapterKit",
            dependencies: [.product(name: "PingFrontCore", package: "pingfront-ios")],
            swiftSettings: upcoming
        ),
        .target(
            name: "PingFrontAdapterTestSupport",
            dependencies: ["PingFrontAdapterKit", .product(name: "PingFrontCore", package: "pingfront-ios")],
            swiftSettings: upcoming
        ),
        .testTarget(
            name: "PingFrontAdapterKitTests",
            dependencies: ["PingFrontAdapterKit", "PingFrontAdapterTestSupport", .product(name: "PingFrontCore", package: "pingfront-ios")],
            swiftSettings: upcoming
        ),
    ],
    swiftLanguageModes: [.v6]
)
