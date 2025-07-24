import StoreKit
import SwiftUI
import Adjust
import PushwooshFramework

@available(iOS 15.0, *)
@MainActor
public final class SK2SubscriptionManager: ObservableObject {
    @Published public private(set) var isSubscribed = false
    @Published public private(set) var isPurchasing = false
    @Published public private(set) var error = ""
    @Published public private(set) var products: [Product] = []
    @Published public var alert: SubscriptionAlert? = nil
    @Published public var isPaywallSkipped: Bool = false
    @Published public var showSubscription: Bool = false
    
    private let localKey = "SubscriptionLocalKey"
    private let productIds: [String]
    private var updatesTask: Task<Void, Never>?
    private var updateCheckTask: Task<Void, Never>?

    public init(productIds: [String]) {
        self.productIds = productIds
        self.isSubscribed = UserDefaults.standard.bool(forKey: localKey)
        
        Task { await self.loadProducts() }
        
        self.updatesTask = observeTransactions()
        
        self.updateCheckTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
            await self?.validateWithServer()
        }
    }
    
    deinit {
        updatesTask?.cancel()
        updateCheckTask?.cancel()
    }

    public func loadProducts() async {
        do {
            self.products = try await Product.products(for: productIds)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Принимает не enum, а любой SubscriptionsProductProtocol!
    public func purchase(_ product: Product) async {
        guard let storeProduct = products.first(where: { $0.id == product.id }) else {
            self.error = "Product not found"
            self.alert = .generalError("Product not found")
            return
        }
        self.isPurchasing = true
        self.error = ""
        defer { self.isPurchasing = false }
        do {
            let result = try await storeProduct.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    self.isSubscribed = true
                    UserDefaults.standard.set(true, forKey: localKey)
                    self.trackSubscription(product: storeProduct, transaction: transaction)
                }
            case .pending:
                let msg = "Your purchase is pending confirmation."
                self.error = msg
                self.alert = .generalError(msg)
            default:
                let msg = "Purchase failed. Please try again later."
                self.error = msg
                self.alert = .generalError(msg)
            }
        } catch {
            self.error = error.localizedDescription
            self.alert = .generalError(error.localizedDescription)
        }
    }

    public func restore() async {
        self.isPurchasing = true
        self.error = ""
        defer { self.isPurchasing = false }
        do {
            let transactions = try await StoreKit.Transaction.currentEntitlements.toArray()
            let found = transactions.contains { result in
                guard case .verified(let t) = result else { return false }
                return productIds.contains(t.productID) && (t.revocationDate == nil) && (t.expirationDate == nil || t.expirationDate! > Date())
            }
            self.isSubscribed = found
            UserDefaults.standard.set(found, forKey: localKey)
            if found {
                self.alert = .restoreSuccess
            } else {
                self.alert = .restoreFailed("No purchases to restore.")
            }
        } catch {
            self.error = error.localizedDescription
            self.alert = .restoreFailed(error.localizedDescription)
        }
    }
    
    public func getPrice(_ product: SubscriptionsProductProtocol) -> String? {
        guard let storeProduct = products.first(where: { $0.id == product.productId }) else { return nil }
        return storeProduct.displayPrice
    }
    
    public func validateWithServer() async {
        do {
            let transactions = try await StoreKit.Transaction.currentEntitlements.toArray()
            let found = transactions.contains { result in
                guard case .verified(let t) = result else { return false }
                return productIds.contains(t.productID) && (t.revocationDate == nil) && (t.expirationDate == nil || t.expirationDate! > Date())
            }
            self.isSubscribed = found
            UserDefaults.standard.set(found, forKey: localKey)
        } catch {
            // Если не удалось проверить — ничего не меняем
        }
    }
    
    // MARK: - Analytics
    private func trackSubscription(product: Product, transaction: StoreKit.Transaction) {
        let price = product.price as NSDecimalNumber
        let currency: String
        if #available(iOS 16.0, *) {
            currency = product.priceFormatStyle.currencyCode
        } else {
            currency = product.priceFormatStyle.locale.currencyCode ?? "USD"
        }
        let region: String
        if #available(iOS 16.0, *) {
            region = product.priceFormatStyle.locale.region?.identifier ?? "US"
        } else {
            region = product.priceFormatStyle.locale.regionCode ?? Locale.current.regionCode ?? "US"
        }
        let transactionId = String(transaction.id)
        let date = transaction.purchaseDate
        if let receiptURL = Bundle.main.appStoreReceiptURL,
           let receiptData = try? Data(contentsOf: receiptURL) {
            if let adjSub = ADJSubscription(price: price, currency: currency, transactionId: transactionId, andReceipt: receiptData) {
                adjSub.setTransactionDate(date)
                adjSub.setSalesRegion(region)
                Adjust.trackSubscription(adjSub)
            }
        }
        Pushwoosh.sharedInstance().setTags(["subscribed": true]) { error in
            if let err = error { print("Pushwoosh error:", err) }
        }
    }
    
    private func observeTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            guard let self else { return }
            for await update in StoreKit.Transaction.updates {
                await self.handle(update)
            }
        }
    }
    
    private func handle(_ update: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = update else { return }
        let isActive = (transaction.revocationDate == nil) &&
        (transaction.expirationDate == nil || transaction.expirationDate! > Date())
        if isActive {
            self.isSubscribed = true
            UserDefaults.standard.set(true, forKey: localKey)
        } else {
            self.isSubscribed = false
            UserDefaults.standard.set(false, forKey: localKey)
        }
    }
}

// AsyncSequence exension (оставь как было)
extension AsyncSequence {
    func toArray() async throws -> [Element] {
        var result: [Element] = []
        for try await item in self { result.append(item) }
        return result
    }
}
