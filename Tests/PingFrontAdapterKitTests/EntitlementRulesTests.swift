import Foundation
import PingFrontAdapterKit
import PingFrontCore
import Testing

@Suite("Entitlement rules")
struct EntitlementRulesTests {
    let renews = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Each vendor state maps to a pingfront state")
    func states() {
        #expect(EntitlementRules.state(of: AccessSnapshot(productId: "a", isActive: true)) == .active)
        #expect(EntitlementRules.state(of: AccessSnapshot(productId: "a", isActive: true, isTrial: true)) == .trial)
        #expect(EntitlementRules.state(of: AccessSnapshot(productId: "a", isActive: true, willRenew: false)) == .cancelled)
        #expect(EntitlementRules.state(of: AccessSnapshot(productId: "a", isActive: true, isTrial: true, willRenew: false)) == .cancelled)
        #expect(EntitlementRules.state(of: AccessSnapshot(productId: "a", isActive: true, hasBillingIssue: true)) == .billingRetry)
        #expect(EntitlementRules.state(of: AccessSnapshot(productId: "a", isActive: true, isInGracePeriod: true)) == .grace)
        #expect(EntitlementRules.state(of: AccessSnapshot(productId: "a", isActive: true, isLifetime: true, willRenew: false)) == .lifetime)
        #expect(EntitlementRules.state(of: AccessSnapshot(productId: "a", isActive: false)) == .expired)
    }

    @Test("The strongest entitlement wins, with its product and renewal date")
    func strongest() {
        let access = [
            AccessSnapshot(productId: "old", isActive: false),
            AccessSnapshot(productId: "monthly", isActive: true, isTrial: true, expiresAt: renews),
            AccessSnapshot(productId: "annual", isActive: true, willRenew: false, expiresAt: renews),
        ]
        let entitlement = EntitlementRules.entitlement(from: access, source: .revenuecat)
        #expect(entitlement == Entitlement(state: .trial, productId: "monthly", renewsAt: renews, source: .revenuecat))
    }

    @Test("Lifetime has no renewal date; nothing is none; only inactive is expired")
    func edges() {
        let lifetime = EntitlementRules.entitlement(
            from: [AccessSnapshot(productId: "forever", isActive: true, isLifetime: true, expiresAt: renews)], source: .adapty)
        #expect(lifetime == Entitlement(state: .lifetime, productId: "forever", source: .adapty))
        #expect(EntitlementRules.entitlement(from: [], source: .superwall) == Entitlement(state: .none, source: .superwall))
        let expired = EntitlementRules.entitlement(from: [AccessSnapshot(productId: "m", isActive: false)], source: .adapty)
        #expect(expired.state == .expired)
    }
}
