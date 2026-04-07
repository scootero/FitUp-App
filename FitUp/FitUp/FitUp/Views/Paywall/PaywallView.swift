//
//  PaywallView.swift
//  FitUp
//
//  Slice 13 — Full paywall sheet backed by RevenueCat.
//  Annual plan is shown first (prominent, gold glass).
//  Monthly plan below (base glass).
//

import Combine
import RevenueCat
import SwiftUI

struct PaywallView: View {
    var onDismiss: () -> Void

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
        .task { await vm.load() }
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
                Task { await vm.purchaseAnnual(); if vm.didPurchase { onDismiss() } }
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
            .disabled(vm.isPurchasingAnnual || vm.isPurchasingMonthly)
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
                Task { await vm.purchaseMonthly(); if vm.didPurchase { onDismiss() } }
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
            .disabled(vm.isPurchasingAnnual || vm.isPurchasingMonthly)
            .padding(.top, 6)
        }
        .padding(16)
        .glassCard(.base)
    }

    // MARK: - Footer actions

    private var restoreButton: some View {
        Button {
            Task { await vm.restore(); if vm.didPurchase { onDismiss() } }
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
    @Published var annualPriceString = "$29.99/year"
    @Published var monthlyPriceString = "$4.99/month"

    @Published var isPurchasingAnnual = false
    @Published var isPurchasingMonthly = false
    @Published var isRestoring = false
    @Published var didPurchase = false
    @Published var showError = false
    @Published var errorMessage: String?

    private var annualPackage: RevenueCat.Package?
    private var monthlyPackage: RevenueCat.Package?

    func load() async {
        let packages = await SubscriptionService.shared.fetchOffering()
        for pkg in packages {
            switch pkg.packageType {
            case .annual:
                annualPackage = pkg
                annualPriceString = pkg.storeProduct.localizedPriceString
            case .monthly:
                monthlyPackage = pkg
                monthlyPriceString = pkg.storeProduct.localizedPriceString
            default:
                break
            }
        }
    }

    func purchaseAnnual() async {
        guard let pkg = annualPackage else {
            showError = true
            errorMessage = "Annual plan not available right now."
            return
        }
        isPurchasingAnnual = true
        defer { isPurchasingAnnual = false }
        do {
            try await SubscriptionService.shared.purchase(package: pkg)
            didPurchase = SubscriptionService.shared.isPremium
        } catch {
            if (error as NSError).code != -128 {
                showError = true
                errorMessage = error.localizedDescription
            }
        }
    }

    func purchaseMonthly() async {
        guard let pkg = monthlyPackage else {
            showError = true
            errorMessage = "Monthly plan not available right now."
            return
        }
        isPurchasingMonthly = true
        defer { isPurchasingMonthly = false }
        do {
            try await SubscriptionService.shared.purchase(package: pkg)
            didPurchase = SubscriptionService.shared.isPremium
        } catch {
            if (error as NSError).code != -128 {
                showError = true
                errorMessage = error.localizedDescription
            }
        }
    }

    func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await SubscriptionService.shared.restorePurchases()
            didPurchase = SubscriptionService.shared.isPremium
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView { }
}
