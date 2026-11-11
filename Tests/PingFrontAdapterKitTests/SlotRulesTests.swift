import Foundation
import PingFrontAdapterKit
import PingFrontAdapterTestSupport
import PingFrontCore
import Testing

@Suite("Slot rules")
struct SlotRulesTests {
    @Test("Ids keep A-Z a-z 0-9 _ . - and replace the rest, up to 64 characters")
    func ids() {
        #expect(SlotRules.id("pro_monthly.v2-a") == "pro_monthly.v2-a")
        #expect(SlotRules.id("Winter sale 50%") == "Winter_sale_50_")
        #expect(SlotRules.id("") == "_")
        #expect(SlotRules.id(String(repeating: "a", count: 80)).count == 64)
    }

    @Test("Titles are trimmed, clipped by code points, and fall back when blank")
    func titles() {
        #expect(SlotRules.title("  Annual plan ", fallback: "x") == "Annual plan")
        #expect(SlotRules.title("   ", fallback: "default") == "default")
        #expect(SlotRules.title(nil, fallback: "default") == "default")
        // 👍🏽 is two code points: 30 of them are 60 code points, the protocol's limit.
        let thumbs = String(repeating: "👍🏽", count: 31)
        #expect(SlotRules.title(thumbs, fallback: "x").unicodeScalars.count == 60)
    }

    @Test("pingfront_kind sets the kind; anything else is standard")
    func kinds() {
        #expect(SlotRules.kind("discount") == .discount)
        #expect(SlotRules.kind(" WinBack ") == .winback)
        #expect(SlotRules.kind("standard") == .standard)
        #expect(SlotRules.kind("vip") == .standard)
        #expect(SlotRules.kind(42) == .standard)
        #expect(SlotRules.kind(nil) == .standard)
    }

    @Test("Periods are ISO-8601")
    func periods() {
        #expect(SlotRules.iso(value: 1, unit: .month) == "P1M")
        #expect(SlotRules.iso(value: 2, unit: .week) == "P2W")
        #expect(SlotRules.iso(value: 0, unit: .year) == nil)
        #expect(SlotRules.iso(value: 1, unit: nil) == nil)
    }

    @Test("A slot is available until the person owns every product in it")
    func availability() {
        #expect(SlotRules.isAvailable(products: [], owned: ["a"]))
        #expect(SlotRules.isAvailable(products: ["a", "b"], owned: ["a"]))
        #expect(!SlotRules.isAvailable(products: ["a", "b"], owned: ["a", "b", "c"]))
    }

    @Test("Prices are clipped to 40 code points")
    func prices() {
        let product = SlotRules.product(id: "p", price: String(repeating: "9", count: 50), period: "P1M", trial: nil)
        #expect(product.price.count == 40)
        #expect(product.period == "P1M")
    }

    @Test("Clamping keeps the first of each id, 20 slots and 10 products each")
    func clamp() {
        let products = (0..<12).map { OfferSlot.Product(id: "p\($0)", price: "€1") }
        var slots = (0..<25).map { OfferSlot(id: "s\($0)", title: "S\($0)", products: products) }
        slots.insert(OfferSlot(id: "s0", title: "Duplicate"), at: 1)
        let clamped = SlotRules.clamp(slots)
        #expect(clamped.count == 20)
        #expect(clamped[0].title == "S0")
        #expect(clamped[1].id == "s1")
        #expect(clamped.allSatisfy { $0.products.count == 10 })
    }

    @Test("Tokens are written as lowercase UUIDs")
    func tokens() {
        #expect(tokenString(sampleToken) == "6f1c2b9e-0d4a-4c7b-9e2f-1a2b3c4d5e6f")
    }
}

@Suite("Slot publisher")
@MainActor struct SlotPublisherTests {
    @Test("Publishes changes only, unless forced, and remembers the source")
    func publishes() {
        let host = FakeHost()
        let publisher = SlotPublisher(host: host, source: .adapty)
        let slots = [OfferSlot(id: "a", title: "A")]
        publisher.publish(slots)
        publisher.publish(slots)
        #expect(host.offers.count == 1)
        publisher.publish(slots, force: true)
        #expect(host.offers.count == 2)
        publisher.publish([])
        #expect(host.offers.count == 3)
        #expect(publisher.source == .adapty)
        #expect(SlotSource.revenuecat.rawValue == "revenuecat")
        #expect(SlotSource.superwall.rawValue == "superwall")
    }
}
