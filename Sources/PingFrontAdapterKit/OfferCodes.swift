public import PingFrontCore
import StoreKit

#if canImport(UIKit)
    import UIKit
#endif

/// Apple's offer code redemption sheet, for `StoreOffer.kind == .code`.
///
/// The redeemed transaction arrives on `Transaction.updates`, where the vendor SDK that owns transactions finishes
/// it; the adapter never touches it.
public enum OfferCodes {
    /// Presents the sheet. `.pending`: the entitlement arrives later, through the vendor.
    @MainActor public static func present() async -> OfferOutcome {
        #if canImport(UIKit)
            guard let scene = Presentation.activeScene() else { return .unavailable }
            do {
                try await AppStore.presentOfferCodeRedeemSheet(in: scene)
                return .pending
            } catch {
                return .failed(.store)
            }
        #else
            return .unavailable
        #endif
    }
}
