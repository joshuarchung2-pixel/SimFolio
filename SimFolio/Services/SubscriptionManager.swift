// SubscriptionManager.swift
// SimFolio - Subscription Management
//
// Manages premium subscription state using RevenueCat.
// Handles purchase flow, subscription status, and entitlement checks.

import Foundation
import Combine
import RevenueCat
import UIKit

enum SubscriptionCheckResult {
    case success(isSubscribed: Bool)
    case failure(Error)
}

@MainActor
class SubscriptionManager: NSObject, ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Published Properties

    @Published var isSubscribed: Bool = UserDefaults.standard.bool(forKey: "lastKnownSubscriptionState") {
        didSet { UserDefaults.standard.set(isSubscribed, forKey: "lastKnownSubscriptionState") }
    }
    @Published var currentOffering: Offering?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var customerInfo: CustomerInfo?
    @Published var currentPlanName: String?
    @Published var expirationDate: Date?
    @Published var willRenew: Bool = false
    @Published var hasBillingIssues: Bool = false

    /// Guards the optimistic `isSubscribed = true` set after a successful
    /// purchase from being overwritten by a delegate callback that arrives
    /// before the entitlement has propagated (common in sandbox).
    private var purchasePending = false
    private(set) var lastSuccessfulCheckDate: Date?

    // MARK: - Configuration

    /// RevenueCat API key loaded from Info.plist (set via xcconfig)
    private var apiKey: String {
        guard let key = Bundle.main.infoDictionary?["RevenueCatAPIKey"] as? String,
              !key.isEmpty,
              key != "$(REVENUECAT_API_KEY)" else {
            #if DEBUG
            // Development: Set REVENUECAT_API_KEY in Secrets.xcconfig
            fatalError("RevenueCat API key not configured. Copy Secrets.xcconfig.example to Secrets.xcconfig and add your key.")
            #else
            let error = AppError.unknown("RevenueCat API key not configured")
            AnalyticsService.logError(error, context: "revenuecat_api_key_missing")
            return ""
            #endif
        }
        return key
    }
    private let entitlementIdentifier = "premium"

    // MARK: - Initialization

    private override init() {
        super.init()
        configureRevenueCat()
    }

    // MARK: - Configuration

    private func configureRevenueCat() {
        let key = apiKey
        guard !key.isEmpty else {
            // Graceful degradation: leave user in non-premium state
            return
        }

        #if DEBUG
        Purchases.logLevel = .debug
        #endif

        Purchases.configure(withAPIKey: key)

        // Listen for customer info updates
        Purchases.shared.delegate = self

        // Check initial subscription status
        Task {
            await checkSubscriptionStatus()
            await fetchOfferings()
        }
    }

    // MARK: - Subscription Status

    @discardableResult
    func checkSubscriptionStatus() async -> SubscriptionCheckResult {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateSubscriptionProperties(from: customerInfo)
            lastSuccessfulCheckDate = Date()
            return .success(isSubscribed: isSubscribed)
        } catch {
            #if DEBUG
            print("Error checking subscription: \(error)")
            #endif
            // Preserve current state on network error — do NOT clear isSubscribed
            return .failure(error)
        }
    }

    /// Updates all subscription properties from CustomerInfo
    private func updateSubscriptionProperties(from customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo

        let entitlement = customerInfo.entitlements[entitlementIdentifier]
        let entitled = entitlement?.isActive == true

        if entitled {
            // Entitlement confirmed — clear the optimistic guard.
            purchasePending = false
        }

        if purchasePending && !entitled {
            // A purchase just succeeded but the entitlement hasn't propagated
            // yet.  Keep the optimistic isSubscribed = true so the paywall
            // stays dismissed.
            #if DEBUG
            print("[SubscriptionManager] Delegate callback blocked — purchasePending=true, entitled=false. Keeping isSubscribed=true.")
            #endif
        } else {
            isSubscribed = entitled
        }

        if let entitlement = entitlement, entitlement.isActive {
            // Extract plan name from product identifier
            currentPlanName = determinePlanName(from: entitlement.productIdentifier)
            expirationDate = entitlement.expirationDate
            willRenew = entitlement.willRenew

            // Check for billing issues
            hasBillingIssues = customerInfo.entitlements[entitlementIdentifier]?.billingIssueDetectedAt != nil
        } else {
            currentPlanName = nil
            expirationDate = nil
            willRenew = false
            hasBillingIssues = false
        }
    }

    /// Determines the plan name from the product identifier
    private func determinePlanName(from productIdentifier: String) -> String {
        let lowercased = productIdentifier.lowercased()
        if lowercased.contains("annual") || lowercased.contains("yearly") || lowercased.contains("year") {
            return "Annual"
        } else if lowercased.contains("monthly") || lowercased.contains("month") {
            return "Monthly"
        } else if lowercased.contains("weekly") || lowercased.contains("week") {
            return "Weekly"
        } else if lowercased.contains("lifetime") {
            return "Lifetime"
        }
        return "Premium"
    }

    // MARK: - Offerings

    func fetchOfferings() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            #if DEBUG
            print("[RevenueCat] Offerings fetched: \(offerings.all.count) offerings")
            print("[RevenueCat] Current offering: \(offerings.current?.identifier ?? "nil")")
            print("[RevenueCat] Available packages: \(offerings.current?.availablePackages.map { $0.identifier } ?? [])")
            #endif

            if let current = offerings.current {
                currentOffering = current
            } else {
                #if DEBUG
                print("[RevenueCat] No current offering available")
                #endif
                errorMessage = "No subscription options available. Please try again later."
            }
        } catch {
            #if DEBUG
            print("[RevenueCat] Error fetching offerings: \(error)")
            #endif
            errorMessage = "Unable to load subscription options: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase

    func purchase(package: Package) async throws -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)

            // Check if the purchase was cancelled
            if result.userCancelled {
                return false
            }

            updateSubscriptionProperties(from: result.customerInfo)

            // Transaction succeeded (not cancelled, no error thrown) — the user
            // has been charged.  Set subscribed optimistically so the paywall
            // can dismiss immediately.  purchasePending prevents delegate
            // callbacks from flipping isSubscribed back to false before the
            // entitlement propagates.
            purchasePending = true
            isSubscribed = true

            // Poll with exponential backoff until entitlement propagates
            if purchasePending {
                let delays: [UInt64] = [1_000_000_000, 2_000_000_000, 4_000_000_000]
                for delay in delays {
                    try? await Task.sleep(nanoseconds: delay)
                    await checkSubscriptionStatus()
                    if !purchasePending { break }
                }
            }

            return true
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Restore

    func restorePurchases() async throws -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateSubscriptionProperties(from: customerInfo)

            if !isSubscribed {
                errorMessage = "No active subscription found to restore."
            }

            return isSubscribed
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Helper Methods

    /// Get the monthly package from current offering
    var monthlyPackage: Package? {
        currentOffering?.availablePackages.first { $0.packageType == .monthly }
    }

    /// Get the annual package from current offering
    var annualPackage: Package? {
        currentOffering?.availablePackages.first { $0.packageType == .annual }
    }

    /// Calculate savings percentage for annual vs monthly
    var annualSavingsPercentage: Int? {
        guard let monthly = monthlyPackage?.storeProduct.price as? NSDecimalNumber,
              let annual = annualPackage?.storeProduct.price as? NSDecimalNumber else {
            return nil
        }

        let monthlyAnnualized = monthly.multiplying(by: 12)
        let savings = monthlyAnnualized.subtracting(annual)
        let percentage = savings.dividing(by: monthlyAnnualized).multiplying(by: 100)

        return Int(percentage.doubleValue.rounded())
    }

    /// Human-readable formatted expiration date
    var formattedExpirationDate: String? {
        guard let date = expirationDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Status summary for UI display
    var subscriptionStatusSummary: String {
        if isSubscribed {
            if hasBillingIssues {
                return "Billing issue - Update payment method"
            }
            if let planName = currentPlanName, let expirationText = formattedExpirationDate {
                if willRenew {
                    return "\(planName) - Renews \(expirationText)"
                } else {
                    return "\(planName) - Expires \(expirationText)"
                }
            }
            return currentPlanName ?? "Active subscription"
        }
        return "Free Plan"
    }

    /// Opens the App Store subscription management page
    func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - PurchasesDelegate

extension SubscriptionManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.updateSubscriptionProperties(from: customerInfo)
        }
    }
}
