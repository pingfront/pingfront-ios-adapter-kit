public import Foundation
public import PingFrontAdapterKit
public import PingFrontCore

/// A host that records what an adapter reports, with a token the test controls.
@MainActor public final class FakeHost: AdapterHost {
    private var storeAccountToken: UUID?
    /// Every `setOffers` call, in order.
    public private(set) var offers: [[OfferSlot]] = []
    /// The source of each `setOffers` call, in order.
    public private(set) var offerSources: [OfferSlot.Source] = []
    /// Every `setEntitlement` call, in order.
    public private(set) var entitlements: [Entitlement] = []
    private var continuations: [AsyncStream<UUID?>.Continuation] = []

    /// Creates a host whose store account token starts as `token`.
    public init(token: UUID? = nil) { storeAccountToken = token }

    /// Records the slots and their source.
    public func setOffers(_ offers: [OfferSlot], from source: OfferSlot.Source) {
        self.offers.append(offers)
        offerSources.append(source)
    }

    /// Records the entitlement.
    public func setEntitlement(_ entitlement: Entitlement) { entitlements.append(entitlement) }

    /// The token now, then every change the test makes.
    public func storeAccountTokenChanges() -> AsyncStream<UUID?> {
        let (stream, continuation) = AsyncStream.makeStream(of: UUID?.self)
        continuation.yield(storeAccountToken)
        continuations.append(continuation)
        return stream
    }

    /// Changes the token, as a new session or a logout would.
    public func setToken(_ token: UUID?) {
        storeAccountToken = token
        continuations.forEach { $0.yield(token) }
    }

    /// The offers last reported.
    public var lastOffers: [OfferSlot]? { offers.last }
}

/// A sleep that returns at once.
public let noSleep: Sleep = { _ in }

/// Yields to other main-actor work until `condition` holds (or gives up).
///
/// Returns whether it held.
@MainActor public func settle(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<2_000 {
        if condition() { return true }
        await Task.yield()
    }
    return condition()
}

/// A fixed token for tests.
public let sampleToken = UUID(uuid: (0x6F, 0x1C, 0x2B, 0x9E, 0x0D, 0x4A, 0x4C, 0x7B, 0x9E, 0x2F, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F))

/// A sleep that only yields, so other main-actor work (the test) runs between checks.
public let yieldingSleep: Sleep = { _ in await Task.yield() }
