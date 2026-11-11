import Foundation
public import PingFrontCore

/// Where a paywall is built (`OfferSlot.source` in the protocol).
public enum SlotSource: String, Sendable, Equatable {
    case revenuecat, superwall, adapty
}

/// The protocol's limits and rules for offer slots.
public enum SlotRules {
    /// At most 20 slots per person.
    public static let maxSlots = 20
    /// At most 10 products per slot.
    public static let maxProducts = 10
    /// Titles are at most 60 code points.
    public static let titleLimit = 60
    /// Prices are at most 40 code points.
    public static let priceLimit = 40
    /// The offering, paywall or remote-config key that sets the slot's kind.
    public static let kindKey = "pingfront_kind"

    /// `OfferSlot.id` allows `[A-Za-z0-9_.-]{1,64}`; other characters become `_`.
    public static func id(_ raw: String) -> String {
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-")
        let mapped = String(raw.map { allowed.contains($0) ? $0 : "_" }.prefix(64))
        return mapped.isEmpty ? "_" : mapped
    }

    /// The first `limit` Unicode code points, as the protocol counts them.
    public static func clip(_ text: String, _ limit: Int) -> String {
        var view = String.UnicodeScalarView()
        view.append(contentsOf: text.unicodeScalars.prefix(limit))
        return String(view)
    }

    /// A display title: trimmed and clipped, falling back to `fallback` when blank.
    public static func title(_ raw: String?, fallback: String) -> String {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clip(trimmed.isEmpty ? fallback : trimmed, titleLimit)
    }

    /// The kind named by `pingfront_kind` metadata: `standard`, `discount` or `winback`; anything else is `standard`.
    public static func kind(_ raw: Any?) -> OfferSlot.Kind {
        guard let text = raw as? String else { return .standard }
        return OfferSlot.Kind(rawValue: text.trimmingCharacters(in: .whitespaces).lowercased()) ?? .standard
    }

    /// A subscription period as ISO-8601 (`P1M`, `P1Y`, `P2W`). `nil` for an unknown unit or a zero value.
    public static func iso(value: Int, unit: PeriodUnit?) -> String? {
        guard value > 0, let unit else { return nil }
        return "P\(value)\(unit.rawValue)"
    }

    /// A slot product with the protocol's limits applied.
    public static func product(id: String, price: String, period: String?, trial: String?) -> OfferSlot.Product {
        OfferSlot.Product(id: id, price: clip(price, priceLimit), period: period, trial: trial)
    }

    /// Available while the person does not own every product in it.
    ///
    /// A slot with no products is available.
    public static func isAvailable(products: [String], owned: Set<String>) -> Bool {
        products.isEmpty || !products.allSatisfy(owned.contains)
    }

    /// Unique ids (the first wins), at most 20 slots, at most 10 products each.
    public static func clamp(_ slots: [OfferSlot]) -> [OfferSlot] {
        var seen = Set<String>()
        var result: [OfferSlot] = []
        for var slot in slots where seen.insert(slot.id).inserted {
            slot.products = Array(slot.products.prefix(maxProducts))
            result.append(slot)
            if result.count == maxSlots { break }
        }
        return result
    }
}

/// Units of a subscription period, with their ISO-8601 letters.
public enum PeriodUnit: String, Sendable {
    case day = "D"
    case week = "W"
    case month = "M"
    case year = "Y"
}

/// Publishes an adapter's slots, skipping repeats of what was last published.
@MainActor public final class SlotPublisher {
    /// Where these slots are built.
    public let source: SlotSource
    private var wireSource: OfferSlot.Source { OfferSlot.Source(rawValue: source.rawValue) ?? .unknown }
    /// What was last published, if anything.
    public private(set) var published: [OfferSlot]?
    private let host: any AdapterHost

    /// Creates a publisher that reports to `host`, tagging slots with `source`.
    public init(host: any AdapterHost, source: SlotSource) {
        self.host = host
        self.source = source
    }

    /// Publishes `slots` (clamped to the protocol's limits) unless they equal the last ones. `force` publishes again,
    /// for a new person.
    public func publish(_ slots: [OfferSlot], force: Bool = false) {
        let clamped = SlotRules.clamp(slots)
        guard force || clamped != published else { return }
        published = clamped
        host.setOffers(
            clamped.map {
                OfferSlot(id: $0.id, title: $0.title, kind: $0.kind, isAvailable: $0.isAvailable, products: $0.products, source: wireSource)
            },
            from: wireSource)
    }
}

/// The parts of an offer card tap the adapters decide on, so the decision logic stays small and testable.
public struct CardTap: Sendable, Equatable {
    /// The `OfferSlot.id` from the card.
    public var offerId: String
    /// The store offer the card redeems.
    public var storeOffer: StoreOffer?

    /// Creates a tap for a slot, with the store offer the card carries.
    public init(offerId: String, storeOffer: StoreOffer? = nil) {
        self.offerId = offerId
        self.storeOffer = storeOffer
    }

    /// The tap described by pingfront's offer request.
    public init(_ request: OfferRequest) { self.init(offerId: request.offerId, storeOffer: request.storeOffer) }
}

/// The app's own paywall for a card: `nil` when the app set none.
public typealias AppOfferHandler = @MainActor () async -> OfferOutcome?
