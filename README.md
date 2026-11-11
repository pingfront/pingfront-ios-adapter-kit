# pingfront adapter kit

The code the pingfront vendor adapters share: offer slot rules, entitlement mapping, the seam to the pingfront SDK's
modules, and presentation helpers. It depends on nothing but the [pingfront iOS SDK](https://github.com/pingfront/pingfront-ios).

You don't add this package yourself. Each adapter brings it in:

- [pingfront-ios-revenuecat](https://github.com/pingfront/pingfront-ios-revenuecat) (`PingFrontRevenueCat`)
- [pingfront-ios-superwall](https://github.com/pingfront/pingfront-ios-superwall) (`PingFrontSuperwall`)
- [pingfront-ios-adapty](https://github.com/pingfront/pingfront-ios-adapty) (`PingFrontAdapty`)

Its API is public only because the adapters are separate packages; apps don't import it.
`PingFrontAdapterTestSupport` holds the fake host the adapters' tests use and is never linked into an app.

See [Modules and vendor adapters](https://pingfront.sh/docs/modules#revenuecat-superwall-and-adapty) in the pingfront
docs. [CHANGELOG.md](CHANGELOG.md). MIT licensed (see `LICENSE`).
