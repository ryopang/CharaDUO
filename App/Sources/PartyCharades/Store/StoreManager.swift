import Core
import Foundation
import Observation
import StoreKit

/// StoreKit 2 front for the game allowance: first 10 games free, a
/// consumable "10 more games" pack, and a one-time "unlimited" unlock.
/// Everything here degrades quietly — a store outage means the paywall shows
/// "unavailable", never a crash, and games already earned always play.
@MainActor
@Observable
final class StoreManager {
    static let packProductID = "com.ryopang.partycharades.games10"
    static let unlimitedProductID = "com.ryopang.partycharades.unlimited"

    private(set) var allowance: GameAllowance
    private(set) var packProduct: Product?
    private(set) var unlimitedProduct: Product?
    private(set) var isPurchasing = false
    private(set) var isLoadingProducts = false
    /// Set when a purchase or restore fails for a reason worth telling the
    /// player; cleared when the paywall is reopened.
    var message: String?

    private let storage: AllowanceStorage
    private var updatesTask: Task<Void, Never>?

    var canStartGame: Bool { allowance.canStartGame }
    var productsLoaded: Bool { packProduct != nil && unlimitedProduct != nil }

    init(storage: AllowanceStorage) {
        self.storage = storage
        self.allowance = storage.load()
    }

    /// Call once at launch. Listens for transactions that finish outside a
    /// purchase call (Ask to Buy approvals, interrupted purchases, refunds).
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    /// Spends one game. Called when a match actually begins.
    func consumeGame() {
        allowance.recordGameStarted()
        storage.save(allowance)
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        guard let products = try? await Product.products(for: [Self.packProductID, Self.unlimitedProductID]) else { return }
        packProduct = products.first { $0.id == Self.packProductID }
        unlimitedProduct = products.first { $0.id == Self.unlimitedProductID }
    }

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await handle(result)
            case .pending:
                message = tr("Waiting for approval. Your games will unlock once it's approved.")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = tr("The purchase couldn't be completed. You haven't been charged.")
        }
    }

    /// Required for the non-consumable. Consumable packs can't be restored —
    /// Apple doesn't keep them — which is why they're stored in the Keychain.
    func restore() async {
        message = nil
        do {
            try await AppStore.sync()
        } catch {
            message = tr("Couldn't reach the App Store. Try again in a moment.")
            return
        }
        await refreshEntitlements()
        if !allowance.hasUnlimited {
            message = tr("No previous purchase to restore.")
        }
    }

    /// Only ever turns unlimited on here. A transient lookup failure must not
    /// take away something the player paid for; revocation arrives through
    /// `Transaction.updates` instead.
    private func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.unlimitedProductID,
                  transaction.revocationDate == nil else { continue }
            if !allowance.hasUnlimited {
                allowance.hasUnlimited = true
                storage.save(allowance)
            }
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        // An unverified transaction is never granted, and never finished, so
        // StoreKit keeps it around rather than us silently dropping a payment.
        guard case .verified(let transaction) = result else { return }
        switch transaction.productID {
        case Self.packProductID:
            if transaction.revocationDate == nil {
                allowance.addPack(transactionID: transaction.id)
                storage.save(allowance)
            }
        case Self.unlimitedProductID:
            allowance.hasUnlimited = transaction.revocationDate == nil
            storage.save(allowance)
        default:
            break
        }
        // Granted and saved above first: a crash before this line redelivers
        // the transaction, and the stored ID stops a second grant.
        await transaction.finish()
    }
}
