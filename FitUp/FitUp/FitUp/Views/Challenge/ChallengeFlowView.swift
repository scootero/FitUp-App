//
//  ChallengeFlowView.swift
//  FitUp
//
//  Slice 4 challenge creation flow root.
//

import SwiftUI

struct ChallengePrefillOpponent: Equatable {
    let id: UUID
    let displayName: String
    let initials: String
    let colorHex: String
}

struct ChallengeLaunchContext: Identifiable, Equatable {
    let id: UUID
    let prefilledOpponent: ChallengePrefillOpponent?
    let prefilledMetric: ChallengeMetricType?
    let prefilledFormat: ChallengeFormatType?

    static var battleEntry: ChallengeLaunchContext {
        ChallengeLaunchContext(
            id: UUID(),
            prefilledOpponent: nil,
            prefilledMetric: nil,
            prefilledFormat: nil
        )
    }

    static func prefilled(opponent: ChallengePrefillOpponent) -> ChallengeLaunchContext {
        ChallengeLaunchContext(
            id: UUID(),
            prefilledOpponent: opponent,
            prefilledMetric: nil,
            prefilledFormat: nil
        )
    }

    static func rematch(
        opponent: ChallengePrefillOpponent,
        metric: ChallengeMetricType,
        format: ChallengeFormatType
    ) -> ChallengeLaunchContext {
        ChallengeLaunchContext(
            id: UUID(),
            prefilledOpponent: opponent,
            prefilledMetric: metric,
            prefilledFormat: format
        )
    }
}

struct ChallengeFlowView: View {
    let profile: Profile?
    let launchContext: ChallengeLaunchContext
    var onClose: () -> Void

    private let matchmakingService: MatchmakingService
    private let directChallengeService: DirectChallengeService

    @State private var stepIndex = 0
    @State private var selectedMetric: ChallengeMetricType?
    @State private var selectedFormat: ChallengeFormatType?
    @State private var selectedOpponent: ChallengeOpponent?
    @State private var isQuickMatch = false
    @State private var query = ""

    @State private var opponents: [ChallengeOpponent] = []
    @State private var isLoadingOpponents = false
    @State private var isCheckingGate = true
    @State private var entryGate: ChallengeEntryGate?
    @State private var showingPaywallSheet = false

    @State private var isSending = false
    @State private var isSent = false
    @State private var sentOpponentName = "your opponent"
    @State private var errorMessage: String?

    @State private var searchTask: Task<Void, Never>?

    init(
        profile: Profile?,
        launchContext: ChallengeLaunchContext,
        onClose: @escaping () -> Void,
        matchmakingService: MatchmakingService = MatchmakingService(),
        directChallengeService: DirectChallengeService = DirectChallengeService()
    ) {
        self.profile = profile
        self.launchContext = launchContext
        self.onClose = onClose
        self.matchmakingService = matchmakingService
        self.directChallengeService = directChallengeService
    }

    var body: some View {
        ZStack {
            BackgroundGradientView()
            content
        }
        .sheet(isPresented: $showingPaywallSheet, onDismiss: {
            if entryGate?.isBlocked == true {
                onClose()
            }
        }) {
            PaywallView {
                showingPaywallSheet = false
            }
        }
        .task {
            await prepareFlow()
        }
        .onChange(of: query) { _, _ in
            reloadOpponentsForQuery()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if isCheckingGate {
                ProgressView("Checking match slot...")
                    .font(FitUpFont.body(13, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .tint(FitUpColors.Neon.cyan)
            } else if entryGate?.isBlocked == true {
                blockedState
            } else {
                mainFlow
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                handleBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(FitUpColors.Neon.cyan)
            }
            .buttonStyle(.plain)

            Text("New Challenge")
                .font(FitUpFont.display(18, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)

            Spacer(minLength: 0)
            Text("⚔️")
                .font(.system(size: 18))
        }
    }

    private var blockedState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Match slot full")
                .font(FitUpFont.display(20, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)
            Text("Free tier supports one open slot across searching, pending, and active matches.")
                .font(FitUpFont.body(13, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
            Button("View Plans") {
                showingPaywallSheet = true
            }
            .buttonStyle(.plain)
            .solidButton(color: FitUpColors.Neon.cyan)
        }
        .padding(20)
        .glassCard(.base)
    }

    @ViewBuilder
    private var mainFlow: some View {
        if !isSent {
            progressStepper
        }

        if let errorMessage, !errorMessage.isEmpty {
            Text(errorMessage)
                .font(FitUpFont.body(12, weight: .semibold))
                .foregroundStyle(FitUpColors.Neon.pink)
                .padding(.horizontal, 2)
        }

        if isSent {
            ChallengeSentView(
                opponentName: sentOpponentName,
                metricLabel: selectedMetric?.displayName ?? "Steps",
                formatLabel: selectedFormat?.displayName ?? "Daily"
            ) {
                onClose()
            }
        } else {
            switch stepIndex {
            case 0:
                SportStepView { metric in
                    selectedMetric = metric
                    stepIndex = 1
                    query = ""
                    reloadOpponentsForQuery()
                }
            case 1:
                FormatStepView { format in
                    selectedFormat = format
                    if selectedOpponent != nil && !isQuickMatch {
                        stepIndex = 3
                    } else {
                        stepIndex = 2
                    }
                }
            case 2:
                OpponentStepView(
                    query: $query,
                    opponents: opponents,
                    isLoading: isLoadingOpponents,
                    onQuickMatch: {
                        isQuickMatch = true
                        selectedOpponent = nil
                        stepIndex = 3
                    },
                    onSelectOpponent: { opponent in
                        selectedOpponent = opponent
                        isQuickMatch = false
                        stepIndex = 3
                    }
                )
            default:
                if let metric = selectedMetric, let format = selectedFormat {
                    ReviewStepView(
                        profile: profile,
                        selectedMetric: metric,
                        selectedFormat: format,
                        selectedOpponent: selectedOpponent,
                        isQuickMatch: isQuickMatch,
                        isSending: isSending
                    ) {
                        Task { await submitChallenge() }
                    }
                }
            }
        }
    }

    private var progressStepper: some View {
        let labels = ["SPORT", "FORMAT", "OPPONENT", "SEND"]
        return HStack(spacing: 6) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index <= stepIndex ? FitUpColors.Neon.cyan : Color.white.opacity(0.1))
                        .frame(height: 3)
                        .shadow(
                            color: index == stepIndex ? FitUpColors.Neon.cyan.opacity(0.7) : .clear,
                            radius: 6,
                            x: 0,
                            y: 0
                        )
                    Text(label)
                        .font(FitUpFont.mono(9, weight: .bold))
                        .foregroundStyle(index == stepIndex ? FitUpColors.Neon.cyan : FitUpColors.Text.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 2)
    }

    @MainActor
    private func prepareFlow() async {
        guard let profile else {
            isCheckingGate = false
            entryGate = ChallengeEntryGate(isBlocked: true, isPremium: false, usedSlots: 1, slotLimit: 1)
            showingPaywallSheet = true
            return
        }

        let gate = await matchmakingService.evaluateEntryGate(profile: profile)
        entryGate = gate
        isCheckingGate = false

        if gate.isBlocked {
            showingPaywallSheet = true
            AppLogger.log(
                category: "paywall",
                level: .info,
                message: "challenge entry blocked at slot limit",
                userId: profile.id,
                metadata: [
                    "used_slots": String(gate.usedSlots),
                    "slot_limit": String(gate.slotLimit),
                ]
            )
            return
        }

        if let prefilledMetric = launchContext.prefilledMetric {
            selectedMetric = prefilledMetric
        }
        if let prefilledFormat = launchContext.prefilledFormat {
            selectedFormat = prefilledFormat
        }

        if let prefill = launchContext.prefilledOpponent {
            selectedOpponent = ChallengeOpponent(
                id: prefill.id,
                displayName: prefill.displayName,
                initials: prefill.initials,
                colorHex: prefill.colorHex,
                todaySteps: nil,
                wins: nil,
                losses: nil,
                rollingStepsBaseline: nil,
                rollingCaloriesBaseline: nil
            )
        }

        await loadOpponents(query: "")
        hydratePrefillFromFetchedOpponents()
        applyLaunchStepIfNeeded()
    }

    @MainActor
    private func submitChallenge() async {
        guard let profileId = profile?.id else { return }
        guard let selectedMetric, let selectedFormat else {
            errorMessage = "Select sport and format before sending."
            return
        }

        errorMessage = nil
        isSending = true
        defer { isSending = false }

        do {
            if isQuickMatch {
                _ = try await matchmakingService.submitQuickMatch(
                    currentUserId: profileId,
                    metricType: selectedMetric,
                    format: selectedFormat,
                    startMode: .today
                )
                sentOpponentName = "a matched opponent"
            } else {
                guard let selectedOpponent else {
                    errorMessage = "Choose an opponent or Quick Match."
                    return
                }
                _ = try await directChallengeService.submitDirectChallenge(
                    challengerId: profileId,
                    opponentId: selectedOpponent.id,
                    metricType: selectedMetric,
                    format: selectedFormat,
                    startMode: .today
                )
                sentOpponentName = selectedOpponent.displayName
            }
            isSent = true
        } catch {
            errorMessage = "Could not send challenge right now."
            AppLogger.log(
                category: "matchmaking",
                level: .warning,
                message: "challenge send failed",
                userId: profileId,
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    private func handleBack() {
        if isSent {
            onClose()
            return
        }
        if stepIndex == 0 {
            onClose()
            return
        }
        if stepIndex == 3 {
            stepIndex = 2
            return
        }
        stepIndex -= 1
    }

    private func reloadOpponentsForQuery() {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            if Task.isCancelled { return }
            await loadOpponents(query: query)
            hydratePrefillFromFetchedOpponents()
        }
    }

    @MainActor
    private func loadOpponents(query: String) async {
        guard let userId = profile?.id else { return }
        let metric = selectedMetric ?? .steps

        isLoadingOpponents = true
        defer { isLoadingOpponents = false }

        do {
            opponents = try await matchmakingService.loadOpponents(
                currentUserId: userId,
                query: query,
                metricType: metric
            )
        } catch {
            opponents = []
            errorMessage = "Could not load opponents."
            AppLogger.log(
                category: "matchmaking",
                level: .warning,
                message: "opponent load failed",
                userId: userId,
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    private func hydratePrefillFromFetchedOpponents() {
        guard let prefill = launchContext.prefilledOpponent else { return }
        if let fetched = opponents.first(where: { $0.id == prefill.id }) {
            selectedOpponent = fetched
        }
    }

    private func applyLaunchStepIfNeeded() {
        let hasMetric = selectedMetric != nil
        let hasFormat = selectedFormat != nil
        let hasOpponent = selectedOpponent != nil

        if hasMetric && hasFormat && hasOpponent {
            isQuickMatch = false
            stepIndex = 3
        } else if hasMetric && hasFormat {
            stepIndex = 2
        } else if hasMetric {
            stepIndex = 1
        }
    }
}


