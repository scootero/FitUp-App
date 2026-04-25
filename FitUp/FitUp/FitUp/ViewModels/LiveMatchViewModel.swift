//
//  LiveMatchViewModel.swift
//  FitUp
//
//  Slice 6 live race state orchestration.
//

import Combine
import Foundation

enum LiveToastTone: Equatable {
    case cyan
    case orange
    case green
}

struct LiveToastItem: Identifiable, Equatable {
    let id: UUID
    let message: String
    let tone: LiveToastTone
}

enum LiveSeriesMarker: Equatable {
    case me
    case opponent
    case pending
}

@MainActor
final class LiveMatchViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var meCount: Int = 0
    @Published var opponentCount: Int = 0
    @Published var meName = "You"
    @Published var opponentName = "Opponent"
    @Published var meInitials = "ME"
    @Published var opponentInitials = "OP"
    @Published var opponentHexColor = "FF6200"
    @Published var isPaused = false
    @Published private(set) var toasts: [LiveToastItem] = []
    @Published private(set) var seriesLabel = MatchDurationCopy.competitionLengthBadge(days: 1)
    @Published private(set) var myScore = 0
    @Published private(set) var theirScore = 0
    @Published private(set) var durationDays = 1
    @Published private(set) var metricType = "steps"
    @Published private(set) var goalValue = 12_000

    let matchId: UUID

    var metricUnitLabel: String {
        metricType == "active_calories" ? "cals" : "steps"
    }

    var leadValue: Int {
        meCount - opponentCount
    }

    var leadLabel: String {
        let amount = abs(leadValue).formatted()
        return "\(amount) \(leadValue >= 0 ? "ahead" : "behind")"
    }

    var isWinning: Bool {
        leadValue >= 0
    }

    var meProgress: Double {
        guard goalValue > 0 else { return 0 }
        return min(1, Double(meCount) / Double(goalValue))
    }

    var opponentProgress: Double {
        guard goalValue > 0 else { return 0 }
        return min(1, Double(opponentCount) / Double(goalValue))
    }

    var meProgressLabel: String {
        "You · \(Int((meProgress * 100).rounded()))%"
    }

    var opponentProgressLabel: String {
        let firstName = opponentName.split(separator: " ").first.map(String.init) ?? opponentName
        return "\(firstName) · \(Int((opponentProgress * 100).rounded()))%"
    }

    var seriesMarkers: [LiveSeriesMarker] {
        let total = max(durationDays, 1)
        return (0..<total).map { index in
            if index < myScore {
                return .me
            }
            if index < myScore + theirScore {
                return .opponent
            }
            return .pending
        }
    }

    private let profile: Profile?
    private let repository: LiveMatchRepository
    private var hasStarted = false
    private var healthRefreshTask: Task<Void, Never>?
    private var seenLead = false
    private var previousLead: Int = 0
    private var reachedMilestones: Set<Int> = []

    init(
        matchId: UUID,
        profile: Profile?,
        repository: LiveMatchRepository
    ) {
        self.matchId = matchId
        self.profile = profile
        self.repository = repository
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        Task { await bootstrap() }
    }

    func stop() {
        hasStarted = false
        healthRefreshTask?.cancel()
        healthRefreshTask = nil
        repository.stopOpponentRealtime()
    }

    func togglePause() {
        isPaused.toggle()
    }

    private func bootstrap() async {
        guard let profile else {
            errorMessage = "You must be signed in to watch live match stats."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let bootstrap = try await repository.loadBootstrap(matchId: matchId, currentUser: profile)
            metricType = bootstrap.metricType
            durationDays = bootstrap.durationDays
            seriesLabel = bootstrap.seriesLabel
            myScore = bootstrap.myScore
            theirScore = bootstrap.theirScore
            meName = "You"
            meInitials = profile.initials
            opponentName = bootstrap.opponent.displayName
            opponentInitials = bootstrap.opponent.initials
            opponentHexColor = bootstrap.opponent.colorHex
            opponentCount = bootstrap.opponentTodayTotal
            goalValue = resolveGoal(for: bootstrap.metricType)
            if errorMessage != nil { errorMessage = nil }

            updateLeadAndToasts()

            repository.startOpponentRealtime(
                matchDayId: bootstrap.matchDayId,
                opponentId: bootstrap.opponent.id
            ) { [weak self] total in
                guard let self else { return }
                await MainActor.run {
                    self.opponentCount = total
                    self.updateLeadAndToasts()
                }
            }

            await refreshMyMetric()
            startHealthRefreshLoop()
        } catch {
            errorMessage = "Could not load live match right now."
            AppLogger.log(
                category: "match_state",
                level: .warning,
                message: "live match bootstrap failed",
                userId: profile.id,
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    private func startHealthRefreshLoop() {
        healthRefreshTask?.cancel()
        healthRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshMyMetric()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func refreshMyMetric() async {
        do {
            let value: Int
            if metricType == "active_calories" {
                value = try await HealthKitService.fetchTodayActiveCalories()
            } else {
                value = try await HealthKitService.fetchTodayStepCount()
            }

            await MainActor.run {
                self.meCount = value
                self.updateLeadAndToasts()
                if self.errorMessage == HealthKitError.authorizationDenied.errorDescription {
                    self.errorMessage = nil
                }
            }
            await MetricSyncCoordinator.shared.requestSync(trigger: .liveMatchRead)
        } catch {
            if let healthError = error as? HealthKitError, case .authorizationDenied = healthError {
                await MainActor.run {
                    self.errorMessage = HealthKitError.authorizationDenied.errorDescription
                }
            }
            if let profile {
                AppLogger.log(
                    category: "healthkit_read",
                    level: .warning,
                    message: "live match metric read failed",
                    userId: profile.id,
                    metadata: [
                        "error": error.localizedDescription,
                        "error_type": String(describing: type(of: error)),
                        "pipeline": "LiveMatchViewModel.refreshMyMetric",
                    ]
                )
            }
        }
    }

    private func updateLeadAndToasts() {
        let currentLead = leadValue

        if seenLead {
            if previousLead < 0, currentLead > 0 {
                enqueueToast("You took the lead!", tone: .cyan)
            } else if previousLead > 0, currentLead < 0 {
                enqueueToast("\(opponentName) took the lead", tone: .orange)
            }
        } else {
            seenLead = true
        }
        previousLead = currentLead

        let milestones = [25, 50, 75, 100]
        for milestone in milestones where !reachedMilestones.contains(milestone) {
            let threshold = Int((Double(goalValue) * Double(milestone) / 100).rounded())
            if meCount >= threshold {
                reachedMilestones.insert(milestone)
                if milestone == 100 {
                    enqueueToast("Goal reached! Great push!", tone: .green)
                } else {
                    enqueueToast("+\(milestone)% toward goal", tone: .cyan)
                }
            }
        }
    }

    private func enqueueToast(_ message: String, tone: LiveToastTone) {
        let item = LiveToastItem(
            id: UUID(),
            message: message,
            tone: tone
        )
        toasts = Array((toasts + [item]).suffix(3))

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            await MainActor.run {
                self?.toasts.removeAll(where: { $0.id == item.id })
            }
        }
    }

    private func resolveGoal(for metricType: String) -> Int {
        if metricType == "active_calories" {
            let value = UserDefaults.standard.integer(forKey: "dailyCaloriesGoal")
            return value > 0 ? value : 500
        }
        let value = UserDefaults.standard.integer(forKey: "dailyStepGoal")
        return value > 0 ? value : 12_000
    }
}
