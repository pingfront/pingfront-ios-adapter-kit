public import Foundation
import Observation
public import PingFrontCore

/// What an adapter needs from pingfront.
///
/// The live host wraps `ModuleContext`; tests use a fake. Adapters never report store events: provider
/// webhooks deliver purchases, renewals and lapses, and they are canonical on the server.
@MainActor public protocol AdapterHost: AnyObject {
    /// Replaces this adapter's offer slots (only those from `source`; other sources keep theirs).
    /// An empty list withdraws them.
    func setOffers(_ offers: [OfferSlot], from source: OfferSlot.Source)
    /// Reports the person's entitlement.
    func setEntitlement(_ entitlement: Entitlement)
    /// The token now, then every change (logout sets it to `nil`, a new session to the new person's token).
    func storeAccountTokenChanges() -> AsyncStream<UUID?>
}

/// The live host: forwards to the `PingFront` instance the module was installed into.
@MainActor public final class ContextHost: AdapterHost {
    private let pingFront: PingFront

    /// Creates the host for the module's context.
    public init(_ context: ModuleContext) { pingFront = context.pingFront }

    /// Reports the adapter's offer slots to pingfront.
    public func setOffers(_ offers: [OfferSlot], from source: OfferSlot.Source) { pingFront.setOffers(offers, from: source) }

    /// Reports the person's entitlement to pingfront.
    public func setEntitlement(_ entitlement: Entitlement) { pingFront.setEntitlement(entitlement) }

    /// The store account token now, then every change.
    public func storeAccountTokenChanges() -> AsyncStream<UUID?> {
        let pingFront = pingFront
        return observedValues { pingFront.storeAccountToken }
    }
}

/// An `@Observable` value now, then each time it changes (repeats are skipped).
@MainActor public func observedValues<Value: Equatable & Sendable>(_ read: @escaping @MainActor () -> Value) -> AsyncStream<Value> {
    AsyncStream { continuation in
        // Owned by the stream: cancelled when the consumer stops iterating.
        let task = Task { @MainActor in
            var last: Value?
            while !Task.isCancelled {
                // Read inside observation tracking, then wait for the next change and read again.
                let (changed, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
                let value = withObservationTracking(read) {
                    signal.yield()
                    signal.finish()
                }
                if last != value {
                    last = value
                    continuation.yield(value)
                }
                for await _ in changed { break }
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}

/// The string form of a store account token that vendor attributes and user ids carry (lowercase UUID).
public func tokenString(_ token: UUID) -> String { token.uuidString.lowercased() }
