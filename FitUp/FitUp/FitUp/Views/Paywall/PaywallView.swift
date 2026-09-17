//
//  PaywallView.swift
//  FitUp
//
//  Slice 13 — Full paywall sheet backed by native StoreKit 2.
//  Monthly FitOff Pro only.
//

import Combine
import SwiftUI

struct PaywallView: View {
    var onDismiss: () -> Void

    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var vm = PaywallViewModel()
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @State private var hasAppeared = false
    @State private var isBreathing = false

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradientView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        headerSection
                        featuresList
                        purchaseArea
                        legalFooter
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
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
                hasAppeared = reduceMotion
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.5)) { hasAppeared = true }
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .alert("Something went wrong", isPresented: $vm.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "Please try again.")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(FitUpColors.Neon.cyan.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 74, height: 74)
                    .scaleEffect(isBreathing ? 1.14 : 0.94)
                    .opacity(isBreathing ? 0.2 : 0.75)
                Circle()
                    .stroke(FitUpColors.Neon.orange.opacity(0.38), lineWidth: 1)
                    .frame(width: 58, height: 58)
                    .scaleEffect(isBreathing ? 0.92 : 1.08)
                Image(systemName: "crown.fill")
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(FitUpColors.Neon.yellow)
                    .shadow(color: FitUpColors.Neon.yellow.opacity(0.5), radius: 10)
            }
            .accessibilityHidden(true)

            Text(SubscriptionConfig.displayName)
                .font(FitUpFont.display(34, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .accessibilityAddTraits(.isHeader)

            Text("More battles. More rivals. No open-match limit.")
                .font(FitUpFont.body(13, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(FitUpColors.Text.secondary)

            Text("\(vm.monthlyPriceLine). Cancel anytime.")
                .font(FitUpFont.body(13, weight: .semibold))
                .foregroundStyle(FitUpColors.Neon.cyan)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Feature bullets

    private var featuresList: some View {
        ProFeatureCard(
            icon: "infinity",
            title: "Unlimited Simultaneous Matches",
            detail: "Keep more than one searching, pending, or active battle open at the same time.",
            tint: FitUpColors.Neon.cyan,
            isVisible: hasAppeared || reduceMotion,
            isBreathing: isBreathing && !reduceMotion
        )
    }

    // MARK: - Purchase

    @ViewBuilder
    private var purchaseArea: some View {
        VStack(spacing: 12) {
            if subscriptionService.isPremium {
                Label("FitOff Pro is active", systemImage: "checkmark.seal.fill")
                    .font(FitUpFont.body(17, weight: .bold))
                    .foregroundStyle(FitUpColors.Neon.green)
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .glassCard(.win)
            } else if subscriptionService.isLoadingProducts {
                HStack(spacing: 10) {
                    ProgressView().tint(FitUpColors.Neon.cyan)
                    Text("Loading FitOff Pro…")
                        .font(FitUpFont.body(16, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .glassCard(.base)
            } else {
                VStack(spacing: 10) {
                    Button {
                        Task {
                            let pid = sessionStore.currentProfile?.id
                            await vm.purchaseMonthly(profileId: pid)
                            if vm.didPurchase { onDismiss() }
                        }
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "crown.fill")
                            if vm.isPurchasingMonthly {
                                ProgressView()
                                    .tint(Color.black)
                                    .scaleEffect(0.85)
                            }
                            VStack(spacing: 2) {
                                Text(vm.isPurchasingMonthly ? "Processing…" : "Subscribe to FitOff Pro")
                                    .font(FitUpFont.body(17, weight: .heavy))
                                if vm.hasMonthlyProduct {
                                    Text(vm.monthlyPriceLine)
                                        .font(FitUpFont.body(12, weight: .bold))
                                }
                            }
                            Image(systemName: "crown.fill")
                        }
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                    }
                    .solidButton(color: FitUpColors.Neon.cyan)
                    .disabled(!vm.hasMonthlyProduct || vm.isPurchasingMonthly || vm.isRestoring)

                    if vm.hasMonthlyProduct {
                        Text("\(vm.monthlyPriceLine), auto-renewing unless cancelled at least 24 hours before renewal.")
                            .font(FitUpFont.body(11, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(FitUpColors.Text.secondary)
                    } else {
                        Text("The monthly plan is unavailable right now. Try again in a moment.")
                            .font(FitUpFont.body(12, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(FitUpColors.Text.secondary)
                        Button("Try Again") { Task { await vm.load() } }
                            .font(FitUpFont.body(13, weight: .semibold))
                            .foregroundStyle(FitUpColors.Neon.cyan)
                    }
                }
            }

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
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .disabled(vm.isRestoring || vm.isPurchasingMonthly)
        }
    }

    private var legalFooter: some View {
        VStack(spacing: 7) {
            HStack(spacing: 16) {
                Link("Privacy", destination: URL(string: "https://fitoff.attune-ai.workers.dev/privacy/")!)
                Link("Apple EULA", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            Text("Payment is charged to your Apple ID after confirmation. Manage or cancel in your Apple account settings.")
                .multilineTextAlignment(.center)
        }
        .font(FitUpFont.body(11, weight: .medium))
        .foregroundStyle(FitUpColors.Text.tertiary)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Feature card

private struct ProFeatureCard: View {
    let icon: String
    let title: String
    let detail: String
    let tint: Color
    let isVisible: Bool
    let isBreathing: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: Circle())
                .scaleEffect(isBreathing ? 1.05 : 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FitUpFont.body(14, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.primary)
                Text(detail)
                    .font(FitUpFont.body(12, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard(.base)
        .overlay {
            RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 7)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - ViewModel

@MainActor
private final class PaywallViewModel: ObservableObject {
    @Published var monthlyPriceString = SubscriptionConfig.unavailablePriceLabel

    @Published var isPurchasingMonthly = false
    @Published var isRestoring = false
    @Published var didPurchase = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var hasMonthlyProduct = false

    var monthlyPriceLine: String {
        guard hasMonthlyProduct else { return SubscriptionConfig.monthlyPriceFallback }
        return "\(monthlyPriceString)/month"
    }

    func load() async {
        let details = await SubscriptionService.shared.loadProducts()
        if let monthly = details?.monthlyDisplayPrice {
            monthlyPriceString = monthly
            hasMonthlyProduct = true
        } else {
            monthlyPriceString = SubscriptionConfig.unavailablePriceLabel
            hasMonthlyProduct = false
        }
    }

    func purchaseMonthly(profileId: UUID?) async {
        if !hasMonthlyProduct {
            await load()
            guard SubscriptionService.shared.monthlyDisplayPrice != nil else {
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
