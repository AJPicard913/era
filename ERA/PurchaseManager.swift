import Foundation
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

@MainActor
final class PurchaseManager: NSObject, ObservableObject {
    @Published var isPro: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var lifetimePriceString: String?

    #if canImport(RevenueCat)
    private var lifetimePackage: Package?
    #endif
    private var lifetimeProductId: String?

    private let entitlementID = "pro"
    private let apiKey = "appl_HTVjkfAHaGkRHCsxAjUrXzuhBMj"

    override init() {
        super.init()
        configure()
    }

    func configure() {
        #if canImport(RevenueCat)
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
        refreshCustomerInfo()
        fetchOfferings()
        #endif
    }

    func fetchOfferings() {
        #if canImport(RevenueCat)
        isLoading = true
        Purchases.shared.getOfferings { [weak self] offerings, error in
            guard let self else { return }
            self.isLoading = false
            if let error {
                self.lastError = error.localizedDescription
                return
            }
            guard let current = offerings?.current else {
                self.lastError = "No current offering configured."
                return
            }

            let names = current.availablePackages.map { "\($0.packageType.rawValue): \($0.storeProduct.productIdentifier)" }
            print("RevenueCat packages:", names)

            if let lifetime = current.availablePackages.first(where: { $0.packageType == .lifetime }) {
                self.lifetimePackage = lifetime
                self.lifetimeProductId = lifetime.storeProduct.productIdentifier
                self.lifetimePriceString = lifetime.storeProduct.localizedPriceString
            } else if let any = current.availablePackages.first {
                self.lifetimePackage = any
                self.lifetimeProductId = any.storeProduct.productIdentifier
                self.lifetimePriceString = any.storeProduct.localizedPriceString
                print("Lifetime package not found, falling back to:", any.storeProduct.productIdentifier)
            } else {
                self.lastError = "No packages available in current offering."
            }
        }
        #endif
    }

    func refreshCustomerInfo() {
        #if canImport(RevenueCat)
        Purchases.shared.getCustomerInfo { [weak self] info, error in
            guard let self else { return }
            if let error {
                self.lastError = error.localizedDescription
                return
            }
            guard let info else { return }
            self.applyCustomerInfo(info)
        }
        #endif
    }

    func buyLifetime() async {
        #if canImport(RevenueCat)
        guard let pkg = lifetimePackage else {
            await MainActor.run { self.lastError = "Lifetime package unavailable." }
            return
        }
        await MainActor.run { isLoading = true; lastError = nil }
        do {
            let result = try await Purchases.shared.purchase(package: pkg)
            await MainActor.run { self.isLoading = false }
            applyCustomerInfo(result.customerInfo)
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
                self.isLoading = false
            }
        }
        #else
        await MainActor.run { lastError = "RevenueCat not available in this build."; isLoading = false }
        #endif
    }

    func restore() async {
        #if canImport(RevenueCat)
        await MainActor.run { isLoading = true; lastError = nil }
        do {
            let info = try await Purchases.shared.restorePurchases()
            await MainActor.run { self.isLoading = false }
            applyCustomerInfo(info)
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
                self.isLoading = false
            }
        }
        #else
        await MainActor.run { lastError = "RevenueCat not available in this build." }
        #endif
    }

    #if canImport(RevenueCat)
    private func applyCustomerInfo(_ info: CustomerInfo) {
        // Primary: entitlement
        var pro = info.entitlements.active[entitlementID] != nil

        // Fallback: if the lifetime product was purchased but entitlement isn't wired yet
        if !pro, let pid = lifetimeProductId {
            let purchased = info.allPurchasedProductIdentifiers
            if purchased.contains(pid) {
                print("Entitlement '\(entitlementID)' not active, but product \(pid) is owned. Treating as Pro (check RC entitlement mapping).")
                pro = true
            }
        }

        // Debug output to help verify configuration while testing
        let activeEntitlements = Array(info.entitlements.active.keys)
        print("Active entitlements:", activeEntitlements)
        print("All purchased product IDs:", info.allPurchasedProductIdentifiers)

        if self.isPro != pro {
            self.isPro = pro
        }
    }
    #endif
}

#if canImport(RevenueCat)
extension PurchaseManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.applyCustomerInfo(customerInfo)
        }
    }
}
#endif