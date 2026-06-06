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
    /// Battle Setup dock hidden until we want the bottom summary chrome again.
    private let showBattleSetupDock = false

    /// Slice 1B: Opponent → Duration → Difficulty (steps-only).
    private enum FlowStep {
        static let opponent = 0
        static let duration = 1
        static let difficulty = 2
    }

    @EnvironmentObject private var sessionStore: SessionStore

    let profile: Profile?
    let launchContext: ChallengeLaunchContext
    var onClose: () -> Void

    private let matchmakingService: MatchmakingService
    private let directChallengeService: DirectChallengeService

    @State private var stepIndex = FlowStep.opponent
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

    @State private var scoringModePreference: MatchScoringModePreference = .raw
    @State private var difficultyPreference: MatchDifficultyPreference = .fair

    private var isDirectedOpponent: Bool {
        !isQuickMatch && selectedOpponent != nil
    }

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
            .environmentObject(sessionStore)
        }
        .task {
            await prepareFlow()
        }
        .onChange(of: query) { _, _ in
            reloadOpponentsForQuery()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showBattleSetupDock,
               !isCheckingGate, entryGate?.isBlocked != true, !isSent {
                challengeBottomChrome
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if isCheckingGate {
                ProgressView("Checking battle slot...")
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

            Text("New Battle")
                .font(FitUpFont.display(18, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)

            Spacer(minLength: 0)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close and return to home")
        }
    }

    private var blockedState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Battle slot full")
                .font(FitUpFont.display(20, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)
            Text("Free tier supports one open slot across searching, pending, and active battles.")
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
                formatLabel: selectedFormat?.displayName ?? MatchDurationCopy.competitionLengthBadge(days: 1)
            ) {
                onClose()
            }
        } else {
            ScrollView {
                flowStepContent
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var flowStepContent: some View {
        switch stepIndex {
        case FlowStep.opponent:
            OpponentStepView(
                query: $query,
                opponents: opponents,
                isLoading: isLoadingOpponents,
                onQuickMatch: {
                    isQuickMatch = true
                    selectedOpponent = nil
                    stepIndex = FlowStep.duration
                },
                onSelectOpponent: { opponent in
                    selectedOpponent = opponent
                    isQuickMatch = false
                    stepIndex = FlowStep.duration
                }
            )
        case FlowStep.duration:
            DurationStepView { format in
                selectedFormat = format
                stepIndex = FlowStep.difficulty
            }
        case FlowStep.difficulty:
            if let metric = selectedMetric, let format = selectedFormat {
                ReviewStepView(
                    profile: profile,
                    selectedMetric: metric,
                    selectedFormat: format,
                    selectedOpponent: selectedOpponent,
                    isQuickMatch: isQuickMatch,
                    isDirectedOpponent: isDirectedOpponent,
                    isSending: isSending,
                    scoringMode: $scoringModePreference,
                    difficulty: $difficultyPreference
                ) {
                    Task { await submitChallenge() }
                }
            }
        default:
            EmptyView()
        }
    }

    private var challengeBottomChrome: some View {
        battleSetupDock
            .padding(.horizontal, FitUpLayout.floatingBottomBarHorizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, FitUpLayout.floatingBottomBarBottomPadding)
            .background {
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(rgb: 0x050810).opacity(0.92),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            }
    }

    private var battleSetupDock: some View {
        ChallengeBattleSetupDock(
            currentStepIndex: stepIndex,
            isQuickMatch: isQuickMatch,
            opponentDisplayName: isQuickMatch ? nil : selectedOpponent?.displayName,
            selectedFormat: selectedFormat,
            scoringMode: scoringModePreference,
            difficulty: difficultyPreference
        )
    }

    private var progressStepper: some View {
        let labels = ["OPPONENT", "DURATION", "DIFFICULTY"]
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
            PaywallLogger.log(
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

        selectedMetric = .steps

        if let prefill = launchContext.prefilledOpponent {
            selectedOpponent = ChallengeOpponent(
                id: prefill.id,
                displayName: prefill.displayName,
                initials: prefill.initials,
                colorHex: prefill.colorHex,
                todaySteps: nil,
                wins: nil,
                losses: nil,
                pastMatchCount: nil,
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
            errorMessage = "Select a battle duration before sending."
            return
        }

        errorMessage = nil
        isSending = true
        defer { isSending = false }

        do {
            if isQuickMatch {
                let scoring = selectedMetric == .steps ? scoringModePreference : nil
                let difficulty = resolvedSubmitDifficulty(for: selectedMetric)
                _ = try await matchmakingService.submitQuickMatch(
                    currentUserId: profileId,
                    metricType: selectedMetric,
                    format: selectedFormat,
                    startMode: .today,
                    scoringMode: scoring,
                    difficulty: difficulty
                )
                sentOpponentName = "a matched opponent"
            } else {
                guard let selectedOpponent else {
                    errorMessage = "Choose an opponent or Quick Battle."
                    return
                }
                let scoring = selectedMetric == .steps ? scoringModePreference : nil
                let difficulty = resolvedSubmitDifficulty(for: selectedMetric)
                _ = try await directChallengeService.submitDirectChallenge(
                    challengerId: profileId,
                    opponentId: selectedOpponent.id,
                    metricType: selectedMetric,
                    format: selectedFormat,
                    startMode: .today,
                    scoringMode: scoring,
                    difficulty: difficulty
                )
                sentOpponentName = selectedOpponent.displayName
            }
            isSent = true
        } catch {
            errorMessage = "Could not send battle right now."
            AppLogger.log(
                category: "matchmaking",
                level: .warning,
                message: "challenge send failed",
                userId: profileId,
                metadata: AppLogger.supabaseErrorMetadata(error)
            )
        }
    }

    private func handleBack() {
        if isSent {
            onClose()
            return
        }
        switch stepIndex {
        case FlowStep.opponent:
            onClose()
        case FlowStep.duration:
            stepIndex = FlowStep.opponent
        case FlowStep.difficulty:
            stepIndex = FlowStep.duration
        default:
            onClose()
        }
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

    private func resolvedSubmitDifficulty(for metric: ChallengeMetricType) -> MatchDifficultyPreference? {
        guard metric == .steps, scoringModePreference == .raw else { return nil }
        if isDirectedOpponent { return .fair }
        return difficultyPreference
    }

    private func applyLaunchStepIfNeeded() {
        if selectedMetric == nil {
            selectedMetric = .steps
        }

        if selectedOpponent != nil, !isQuickMatch {
            isQuickMatch = false
            stepIndex = FlowStep.duration
        } else {
            stepIndex = FlowStep.opponent
        }
    }
}


