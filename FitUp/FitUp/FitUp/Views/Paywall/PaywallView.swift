//
//  PaywallView.swift
//  FitUp
//
//  Slice 13 — Paywall sheet backed by RevenueCat.
//  Launch: monthly Pro at $2.99 with 7-day free trial (intro offer from StoreKit).
//

import Combine
import RevenueCat
import SwiftUI

struct PaywallView: View {
    var onDismiss: () -> Void

    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.openURL) private var openURL
    @StateObject private var vm = PaywallViewModel()

    var body: some View {
        ZStack {
            BackgroundGradientView()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    featuresList
                    plansSection
                    legalLinks
                    restoreButton
                    dismissButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 40)
            }
        }
        .task {
            await vm.load()
        }
        .onAppear {
            ProductAnalytics.track(
                ProductAnalytics.Event.subscriptionScreenViewed,
                userId: sessionStore.currentProfile?.id
            )
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert("Something went wrong", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Please try again.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Upgrade to")
                .font(FitUpFont.body(15, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.secondary)

            Text("FitUp Pro")
                .font(FitUpFont.display(32, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)

            Text("Unlimited battles. Every duration. No cooldown.")
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
        }
    }

    // MARK: - Feature bullets

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 10) {
            FeatureBullet(icon: "infinity", text: "Unlimited simultaneous matches")
            FeatureBullet(icon: "calendar", text: "1-, 3-, 5-, and 7-day battles")
            FeatureBullet(icon: "person.2.fill", text: "Challenge anyone in FitUp")
            FeatureBullet(icon: "chart.bar.fill", text: "Live leaderboard & streak bonuses")
        }
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(spacing: 12) {
            monthlyCard
        }
    }

    private var monthlyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                NeonBadge(label: "PRO MONTHLY", color: FitUpColors.Neon.yellow)
                Spacer()
                if vm.hasFreeTrial {
                    NeonBadge(label: "7-DAY FREE TRIAL", color: FitUpColors.Neon.cyan)
                }
            }

            Text(vm.monthlyPriceString)
                .font(FitUpFont.display(26, weight: .black))
                .foregroundStyle(FitUpColors.Neon.yellow)

            Text(vm.billingSubtitle)
                .font(FitUpFont.body(12, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)

            Text("Free: one 3-day battle, then wait until the day after it ends. Pro removes limits.")
                .font(FitUpFont.body(12, weight: .medium))
                .foregroundStyle(FitUpColors.Text.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            Button {
                Task {
                    let pid = sessionStore.currentProfile?.id
                    await vm.purchaseMonthly(profileId: pid)
                    if vm.didPurchase { onDismiss() }
                }
            } label: {
                HStack(spacing: 8) {
                    if vm.isPurchasingMonthly {
                        ProgressView()
                            .tint(Color.black)
                            .scaleEffect(0.85)
                    }
                    Text(vm.isPurchasingMonthly ? "Processing…" : vm.ctaTitle)
                        .font(FitUpFont.body(15, weight: .heavy))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .solidButton(color: FitUpColors.Neon.cyan)
            .disabled(vm.isPurchasingMonthly)
            .padding(.top, 6)
        }
        .padding(16)
        .glassCard(.gold)
    }

    // MARK: - Footer actions

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Button("Privacy Policy") {
                if let url = URL(string: FitUpAppLinks.privacyPolicyURL) {
                    openURL(url)
                }
            }
            Button("Terms of Use") {
                if let url = URL(string: FitUpAppLinks.termsOfUseURL) {
                    openURL(url)
                }
            }
        }
        .font(FitUpFont.body(12, weight: .semibold))
        .foregroundStyle(FitUpColors.Neon.cyan)
        .frame(maxWidth: .infinity)
    }

    private var restoreButton: some View {
        Button {
            Task {
                let pid = sessionStore.currentProfile?.id
                await vm.restore(profileId: pid)
                if vm.didPurchase { onDismiss() }
            }
        } label: {
            HStack(spacing: 6) {
                if vm.isRestoring {
                    ProgressView()
                        .tint(FitUpColors.Neon.cyan)
                        .scaleEffect(0.75)
                }
                Text(vm.isRestoring ? "Restoring…" : "Restore Purchases")
                    .font(FitUpFont.body(13, weight: .semibold))
            }
            .foregroundStyle(FitUpColors.Neon.cyan)
            .frame(maxWidth: .infinity)
        }
        .disabled(vm.isRestoring || vm.isPurchasingMonthly)
    }

    private var dismissButton: some View {
        Button("Not now") { onDismiss() }
            .font(FitUpFont.body(13, weight: .medium))
            .foregroundStyle(FitUpColors.Text.tertiary)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Feature bullet

private struct FeatureBullet: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FitUpColors.Neon.cyan)
                .frame(width: 20)

            Text(text)
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.primary)
        }
    }
}

// MARK: - ViewModel

@MainActor
private final class PaywallViewModel: ObservableObject {
    @Published var monthlyPriceString = "$2.99/month"
    @Published var hasFreeTrial = true
    @Published var isPurchasingMonthly = false
    @Published var isRestoring = false
    @Published var didPurchase = false
    @Published var showError = false
    @Published var errorMessage: String?

    private var monthlyPackage: RevenueCat.Package?

    var billingSubtitle: String {
        if hasFreeTrial {
            return "7 days free, then \(monthlyPriceString) · billed monthly · cancel anytime"
        }
        return "per month · billed monthly · cancel anytime"
    }

    var ctaTitle: String {
        hasFreeTrial ? "Start Free Trial" : "Subscribe Monthly"
    }

    func load() async {
        let packages = await SubscriptionService.shared.fetchOffering()
        for pkg in packages {
            switch pkg.packageType {
            case .monthly:
                monthlyPackage = pkg
                monthlyPriceString = pkg.storeProduct.localizedPriceString
                if let intro = pkg.storeProduct.introductoryDiscount {
                    hasFreeTrial = intro.paymentMode == .freeTrial
                } else {
                    // Keep trial CTA until ASC intro offer is attached and packages load.
                    hasFreeTrial = true
                }
            default:
                break
            }
        }
    }

    func purchaseMonthly(profileId: UUID?) async {
        guard let pkg = monthlyPackage else {
            showError = true
            errorMessage = "Monthly plan not available right now. Check your App Store / RevenueCat setup."
            return
        }
        isPurchasingMonthly = true
        defer { isPurchasingMonthly = false }
        if let profileId {
            ProductAnalytics.track(
                ProductAnalytics.Event.subscriptionPurchaseStarted,
                userId: profileId,
                properties: ["package": "monthly"]
            )
        }
        do {
            try await SubscriptionService.shared.purchase(package: pkg)
            didPurchase = SubscriptionService.shared.isPremium
            if let profileId, didPurchase {
                ProductAnalytics.track(
                    ProductAnalytics.Event.subscriptionPurchaseSucceeded,
                    userId: profileId,
                    properties: ["package": "monthly"]
                )
            }
        } catch {
            let ns = error as NSError
            if let profileId, ns.code != -128 {
                ProductAnalytics.track(
                    ProductAnalytics.Event.subscriptionPurchaseFailed,
                    userId: profileId,
                    properties: ["package": "monthly", "code": "\(ns.code)"]
                )
            }
            if ns.code != -128 {
                showError = true
                errorMessage = error.localizedDescription
            }
        }
    }

    func restore(profileId: UUID?) async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await SubscriptionService.shared.restorePurchases()
            didPurchase = SubscriptionService.shared.isPremium
            if let profileId, didPurchase {
                ProductAnalytics.track(
                    ProductAnalytics.Event.subscriptionRestoreSucceeded,
                    userId: profileId,
                    properties: ["tier": SubscriptionService.shared.isPremium ? "premium" : "free"]
                )
            }
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView { }
        .environmentObject(SessionStore())
}
