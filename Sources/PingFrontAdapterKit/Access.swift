public import Foundation
public import PingFrontCore

/// One vendor entitlement (RevenueCat entitlement, Superwall entitlement, Adapty access level), reduced to what
/// pingfront's entitlement states need.
public struct AccessSnapshot: Sendable, Equatable {
    /// The store product behind it, if the vendor names one.
    public var productId: String?
    /// Whether it grants access now.
    public var isActive: Bool
    /// Whether it never expires (a non-consumable or lifetime purchase).
    public var isLifetime: Bool
    /// Whether the person is in a free trial.
    public var isTrial: Bool
    /// Whether it renews at the end of the period (`false` when auto-renew is off).
    public var willRenew: Bool
    /// Whether the store's billing grace period is running.
    public var isInGracePeriod: Bool
    /// Whether the store could not charge the person (billing retry).
    public var hasBillingIssue: Bool
    /// When access ends, if it ends.
    public var expiresAt: Date?

    /// Creates a snapshot; only the product and whether it is active are required.
    public init(
        productId: String?, isActive: Bool, isLifetime: Bool = false, isTrial: Bool = false, willRenew: Bool = true,
        isInGracePeriod: Bool = false, hasBillingIssue: Bool = false, expiresAt: Date? = nil
    ) {
        self.productId = productId
        self.isActive = isActive
        self.isLifetime = isLifetime
        self.isTrial = isTrial
        self.willRenew = willRenew
        self.isInGracePeriod = isInGracePeriod
        self.hasBillingIssue = hasBillingIssue
        self.expiresAt = expiresAt
    }
}

/// What the vendor knows about the person: their entitlements and the products they own now.
public struct AccessState: Sendable, Equatable {
    /// The person's entitlements, in the vendor's order.
    public var access: [AccessSnapshot]
    /// The product ids the person owns now.
    public var owned: Set<String>

    /// Creates a state; empty by default.
    public init(access: [AccessSnapshot] = [], owned: Set<String> = []) {
        self.access = access
        self.owned = owned
    }
}

/// Maps vendor entitlements to pingfront's entitlement states.
public enum EntitlementRules {
    /// One entitlement's state: inactive is `expired`; then lifetime, grace, billing retry, auto-renew off
    /// (`cancelled`), trial, `active`.
    public static func state(of access: AccessSnapshot) -> Entitlement.State {
        guard access.isActive else { return .expired }
        if access.isLifetime { return .lifetime }
        if access.isInGracePeriod { return .grace }
        if access.hasBillingIssue { return .billingRetry }
        if !access.willRenew { return .cancelled }
        if access.isTrial { return .trial }
        return .active
    }

    /// The strongest entitlement, as the StoreKit module ranks them. `none` when there is nothing.
    public static func entitlement(from access: [AccessSnapshot], source: Entitlement.Source) -> Entitlement {
        var best = Entitlement(state: .none, source: source)
        for item in access {
            let state = state(of: item)
            guard rank(state) > rank(best.state) else { continue }
            let renews = state == .lifetime ? nil : item.expiresAt
            best = Entitlement(state: state, productId: item.productId, renewsAt: renews, source: source)
        }
        return best
    }

    /// Stronger states rank higher.
    public static func rank(_ state: Entitlement.State) -> Int {
        switch state {
        case .lifetime: 7
        case .active: 6
        case .trial: 5
        case .grace: 4
        case .billingRetry: 3
        case .cancelled: 2
        case .expired: 1
        case .none, .unknown: 0
        // A state a later SDK adds ranks with `unknown` until this adapter learns it.
        @unknown default: 0
        }
    }
}
