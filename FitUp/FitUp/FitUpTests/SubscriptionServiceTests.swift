import XCTest
@testable import FitUp

@MainActor
final class SubscriptionServiceTests: XCTestCase {

    func testDebugProForcesAccessWithoutStoreEntitlement() async {
        let store = FakeSubscriptionStoreClient()
        store.hasEntitlement = false
        let service = makeService(store)

        #if DEBUG
        service.debugMode = .pro
        XCTAssertTrue(service.isPremium)
        XCTAssertFalse(service.isSubscribed)
        #else
        XCTAssertFalse(service.isPremium)
        #endif
    }

    func testDebugFreeDeniesAccessDespiteStoreEntitlement() async {
        let store = FakeSubscriptionStoreClient()
        store.hasEntitlement = true
        let service = makeService(store)
        await service.refreshEntitlement()

        #if DEBUG
        service.debugMode = .free
        XCTAssertTrue(service.isSubscribed)
        XCTAssertFalse(service.isPremium)
        #else
        XCTAssertTrue(service.isPremium)
        #endif
    }

    func testDebugSystemFollowsStoreKitEntitlement() async {
        let store = FakeSubscriptionStoreClient()
        store.hasEntitlement = false
        let service = makeService(store)

        #if DEBUG
        service.debugMode = .system
        #endif

        await service.refreshEntitlement()
        XCTAssertFalse(service.isPremium)

        store.hasEntitlement = true
        await service.refreshEntitlement()
        XCTAssertTrue(service.isPremium)
    }

    func testSuccessfulPurchaseUnlocksSystemEntitlement() async {
        let store = FakeSubscriptionStoreClient()
        let service = makeService(store)
        #if DEBUG
        service.debugMode = .system
        #endif

        await service.refresh()
        let state = await service.purchase(plan: .monthly)

        XCTAssertTrue(service.isSubscribed)
        XCTAssertTrue(service.isPremium)
        XCTAssertEqual(state, .purchased)
    }

    func testPendingAndCancelledPurchasesStayUsable() async {
        let store = FakeSubscriptionStoreClient()
        let service = makeService(store)
        await service.refresh()

        store.purchaseOutcome = .pending
        let pending = await service.purchase(plan: .monthly)
        XCTAssertEqual(pending, .pending)
        XCTAssertFalse(service.isBusy)

        store.purchaseOutcome = .cancelled
        let cancelled = await service.purchase(plan: .monthly)
        XCTAssertEqual(cancelled, .cancelled)
        XCTAssertFalse(service.isBusy)
    }

    func testRestoreUnlocksActiveEntitlement() async {
        let store = FakeSubscriptionStoreClient()
        store.entitlementAfterRestore = true
        let service = makeService(store)
        #if DEBUG
        service.debugMode = .system
        #endif

        let state = await service.restorePurchases()
        XCTAssertEqual(state, .restored)
        XCTAssertTrue(service.isPremium)
    }

    func testRestoreWithoutEntitlementStaysFree() async {
        let store = FakeSubscriptionStoreClient()
        let service = makeService(store)
        #if DEBUG
        service.debugMode = .system
        #endif

        let state = await service.restorePurchases()
        XCTAssertEqual(state, .noActiveSubscription)
        XCTAssertFalse(service.isPremium)
        XCTAssertFalse(service.isBusy)
    }

    func testEntitlementExpirationRemovesAccessOnRefresh() async {
        let store = FakeSubscriptionStoreClient()
        store.hasEntitlement = true
        let service = makeService(store)
        #if DEBUG
        service.debugMode = .system
        #endif

        await service.refreshEntitlement()
        XCTAssertTrue(service.isPremium)

        store.hasEntitlement = false
        await service.refreshEntitlement()
        XCTAssertFalse(service.isPremium)
    }

    func testPurchaseFailureDoesNotLeaveBusyState() async {
        let store = FakeSubscriptionStoreClient()
        store.purchaseError = TestError.expected
        let service = makeService(store)
        await service.refresh()

        let state = await service.purchase(plan: .monthly)
        XCTAssertTrue(state.isFailure)
        XCTAssertFalse(service.isBusy)
    }

    func testCanCreateMatchHonorsPremiumAndFreeSlotLimit() {
        let store = FakeSubscriptionStoreClient()
        let service = makeService(store)

        #if DEBUG
        service.debugMode = .free
        #endif
        XCTAssertTrue(service.canCreateMatch(usedSlots: 0))
        XCTAssertFalse(service.canCreateMatch(usedSlots: 1))

        #if DEBUG
        service.debugMode = .pro
        XCTAssertTrue(service.canCreateMatch(usedSlots: 5))
        #endif
    }

    func testProductIDsMatchExpectedStoreKitIdentifiers() {
        XCTAssertEqual(SubscriptionConfig.monthlyProductID, "com.ScottOliver.FitUp.Monthly")
        XCTAssertEqual(SubscriptionConfig.allProductIDs, ["com.ScottOliver.FitUp.Monthly"])
    }

    func testUnavailableProductsDoNotExposeFallbackAsLoadedPrice() async {
        let store = FakeSubscriptionStoreClient()
        store.productsAvailable = false
        let service = makeService(store)

        let details = await service.loadProducts()
        XCTAssertNil(details?.monthlyDisplayPrice)
        XCTAssertNil(service.monthlyDisplayPrice)
    }

    private func makeService(_ store: FakeSubscriptionStoreClient) -> SubscriptionService {
        SubscriptionService(
            storeClient: store,
            listenForTransactions: false,
            automaticallyRefresh: false,
            persistsDebugModeChanges: false
        )
    }
}

@MainActor
private final class FakeSubscriptionStoreClient: SubscriptionStoreClient {
    var hasEntitlement = false
    var entitlementAfterRestore = false
    var productsAvailable = true
    var purchaseOutcome: SubscriptionPurchaseOutcome = .purchased
    var purchaseError: Error?
    var restoreError: Error?
    var purchaseCallCount = 0

    func loadProducts() async throws -> SubscriptionProductDetails {
        guard productsAvailable else {
            return SubscriptionProductDetails(monthlyDisplayPrice: nil)
        }
        return SubscriptionProductDetails(monthlyDisplayPrice: "$2.99")
    }

    func purchase(_ plan: SubscriptionPlan) async throws -> SubscriptionPurchaseOutcome {
        purchaseCallCount += 1
        if let purchaseError { throw purchaseError }
        if purchaseOutcome == .purchased {
            hasEntitlement = true
        }
        return purchaseOutcome
    }

    func restorePurchases() async throws {
        if let restoreError { throw restoreError }
        if entitlementAfterRestore {
            hasEntitlement = true
        }
    }

    func hasActiveProEntitlement() async -> Bool {
        hasEntitlement
    }
}

private enum TestError: Error {
    case expected
}
