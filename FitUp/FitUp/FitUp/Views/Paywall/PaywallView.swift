//
//  PaywallView.swift
//  FitUp
//
//  Slice 13 — Full paywall sheet backed by native StoreKit 2.
//  Annual plan is shown first (prominent, gold glass).
//  Monthly plan below (base glass).
//

import Combine
import SwiftUI

struct PaywallView: View {
    var onDismiss: () -> Void

    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var vm = PaywallViewModel()

    var body: some View {
        ZStack {
            BackgroundGradientView()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    featuresList
                    plansSection
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

            Text("Compete without limits.")
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
        }
    }

    // MARK: - Feature bullets

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 10) {
            FeatureBullet(icon: "infinity", text: "Unlimited simultaneous matches")
            FeatureBullet(icon: "chart.bar.fill", text: "Live leaderboard & streak bonuses")
            FeatureBullet(icon: "bolt.fill", text: "Priority matchmaking & detailed stats")
        }
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(spacing: 12) {
            annualCard
            monthlyCard
        }
    }

    private var annualCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                NeonBadge(label: "BEST VALUE", color: FitUpColors.Neon.yellow)
                Spacer()
                NeonBadge(label: "SAVE 58%", color: FitUpColors.Neon.yellow)
            }

            Text(vm.annualPriceString)
                .font(FitUpFont.display(26, weight: .black))
                .foregroundStyle(FitUpColors.Neon.yellow)

            Text("per year · billed annually")
                .font(FitUpFont.body(12, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)

            Button {
                Task {
                    let pid = sessionStore.currentProfile?.id
                    await vm.purchaseAnnual(profileId: pid)
                    if vm.didPurchase { onDismiss() }
                }
            } label: {
                HStack(spacing: 8) {
                    if vm.isPurchasingAnnual {
                        ProgressView()
                            .tint(Color.black)
                            .scaleEffect(0.85)
                    }
                    Text(vm.isPurchasingAnnual ? "Processing…" : "Subscribe Annually")
                        .font(FitUpFont.body(15, weight: .heavy))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .solidButton(color: FitUpColors.Neon.cyan)
            .disabled(vm.isPurchasingAnnual || vm.isPurchasingMonthly || vm.isRestoring)
            .padding(.top, 6)
        }
        .padding(16)
        .glassCard(.gold)
    }

    private var monthlyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vm.monthlyPriceString)
                .font(FitUpFont.display(20, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)

            Text("per month · billed monthly")
                .font(FitUpFont.body(12, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)

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
                            .tint(FitUpColors.Neon.cyan)
                            .scaleEffect(0.85)
                    }
                    Text(vm.isPurchasingMonthly ? "Processing…" : "Subscribe Monthly")
                        .font(FitUpFont.body(15, weight: .heavy))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .ghostButton(color: FitUpColors.Neon.cyan)
            .disabled(vm.isPurchasingAnnual || vm.isPurchasingMonthly || vm.isRestoring)
            .padding(.top, 6)
        }
        .padding(16)
        .glassCard(.base)
    }

    // MARK: - Footer actions

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
        .disabled(vm.isRestoring || vm.isPurchasingAnnual || vm.isPurchasingMonthly)
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
    @Published var annualPriceString = SubscriptionConfig.annualPriceFallback
    @Published var monthlyPriceString = SubscriptionConfig.monthlyPriceFallback

    @Published var isPurchasingAnnual = false
    @Published var isPurchasingMonthly = false
    @Published var isRestoring = false
    @Published var didPurchase = false
    @Published var showError = false
    @Published var errorMessage: String?

    private var hasAnnualProduct = false
    private var hasMonthlyProduct = false

    func load() async {
        let details = await SubscriptionService.shared.loadProducts()
        if let monthly = details?.monthlyDisplayPrice {
            monthlyPriceString = monthly
            hasMonthlyProduct = true
        } else {
            monthlyPriceString = SubscriptionService.shared.monthlyPriceString
            hasMonthlyProduct = false
        }
        if let annual = details?.annualDisplayPrice {
            annualPriceString = annual
            hasAnnualProduct = true
        } else {
            annualPriceString = SubscriptionService.shared.annualPriceString
            hasAnnualProduct = false
        }
    }

    func purchaseAnnual(profileId: UUID?) async {
        if !hasAnnualProduct {
            await load()
            guard SubscriptionService.shared.productDetails?.annualDisplayPrice != nil else {
                showError = true
                errorMessage = "Annual plan not available right now."
                return
            }
            hasAnnualProduct = true
        }

        isPurchasingAnnual = true
        defer { isPurchasingAnnual = false }
        if let profileId {
            ProductAnalytics.track(
                ProductAnalytics.Event.subscriptionPurchaseStarted,
                userId: profileId,
                properties: ["package": "annual"]
            )
        }

        let state = await SubscriptionService.shared.purchase(plan: .annual)
        handlePurchaseState(state, package: "annual", profileId: profileId)
    }

    func purchaseMonthly(profileId: UUID?) async {
        if !hasMonthlyProduct {
            await load()
            guard SubscriptionService.shared.productDetails?.monthlyDisplayPrice != nil else {
                showError = true
                errorMessage = "Monthly plan not available right now."
                return
            }
            hasMonthlyProduct = true
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

        let state = await SubscriptionService.shared.purchase(plan: .monthly)
        handlePurchaseState(state, package: "monthly", profileId: profileId)
    }

    func restore(profileId: UUID?) async {
        isRestoring = true
        defer { isRestoring = false }

        let state = await SubscriptionService.shared.restorePurchases()
        switch state {
        case .restored:
            didPurchase = true
            if let profileId {
                ProductAnalytics.track(
                    ProductAnalytics.Event.subscriptionRestoreSucceeded,
                    userId: profileId,
                    properties: ["tier": "premium"]
                )
            }
        case .noActiveSubscription:
            showError = true
            errorMessage = state.message
        case .failed(let message):
            showError = true
            errorMessage = message
        default:
            break
        }
    }

    private func handlePurchaseState(
        _ state: SubscriptionActionState,
        package: String,
        profileId: UUID?
    ) {
        switch state {
        case .purchased:
            didPurchase = SubscriptionService.shared.isPremium
            if let profileId, didPurchase {
                ProductAnalytics.track(
                    ProductAnalytics.Event.subscriptionPurchaseSucceeded,
                    userId: profileId,
                    properties: ["package": package]
                )
            }
        case .cancelled:
            break
        case .pending:
            showError = true
            errorMessage = state.message
        case .failed(let message):
            if let profileId {
                ProductAnalytics.track(
                    ProductAnalytics.Event.subscriptionPurchaseFailed,
                    userId: profileId,
                    properties: ["package": package, "code": "failed"]
                )
            }
            showError = true
            errorMessage = message
        default:
            break
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView { }
        .environmentObject(SessionStore())
}
