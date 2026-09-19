import Foundation
import Supabase

struct AccountDeletionPreparation: Decodable, Sendable {
    let operationId: UUID
    let requiresAppleAuthorization: Bool

    enum CodingKeys: String, CodingKey {
        case operationId = "operation_id"
        case requiresAppleAuthorization = "requires_apple_authorization"
    }
}

struct AccountDeletionResult: Decodable, Sendable {
    let status: String
    let operationId: UUID

    enum CodingKeys: String, CodingKey {
        case status
        case operationId = "operation_id"
    }
}

struct AccountDeletionFailure: LocalizedError, Sendable {
    let operationId: UUID
    let code: String

    var errorDescription: String? {
        "Account deletion could not be completed. Please try again. Operation ID: \(operationId.uuidString)"
    }
}

protocol AccountDeletionServicing: Sendable {
    func prepare(operationId: UUID) async throws -> AccountDeletionPreparation
    func delete(operationId: UUID, appleAuthorizationCode: String?) async throws -> AccountDeletionResult
}

final class AccountDeletionService: AccountDeletionServicing, @unchecked Sendable {
    private struct FailureBody: Decodable {
        let errorCode: String?
        let operationId: UUID?

        enum CodingKeys: String, CodingKey {
            case errorCode = "error_code"
            case operationId = "operation_id"
        }
    }

    func prepare(operationId: UUID) async throws -> AccountDeletionPreparation {
        try await invoke(
            operationId: operationId,
            body: AccountDeletionRequest(operationId: operationId, mode: "prepare", appleAuthorizationCode: nil)
        )
    }

    func delete(operationId: UUID, appleAuthorizationCode: String?) async throws -> AccountDeletionResult {
        try await invoke(
            operationId: operationId,
            body: AccountDeletionRequest(
                operationId: operationId,
                mode: "delete",
                appleAuthorizationCode: appleAuthorizationCode
            )
        )
    }

    private func invoke<Response: Decodable>(operationId: UUID, body: AccountDeletionRequest) async throws -> Response {
        guard let client = SupabaseProvider.client else {
            throw AccountDeletionFailure(operationId: operationId, code: "not_configured")
        }
        do {
            let session = try await client.auth.session
            return try await client.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(
                    headers: ["Authorization": "Bearer \(session.accessToken)"],
                    body: body
                )
            )
        } catch let FunctionsError.httpError(_, data) {
            let failure = try? JSONDecoder().decode(FailureBody.self, from: data)
            throw AccountDeletionFailure(
                operationId: failure?.operationId ?? operationId,
                code: failure?.errorCode ?? "request_failed"
            )
        } catch {
            throw AccountDeletionFailure(operationId: operationId, code: "request_failed")
        }
    }
}

private struct AccountDeletionRequest: Encodable, Sendable {
    let operationId: UUID
    let mode: String
    let appleAuthorizationCode: String?

    enum CodingKeys: String, CodingKey {
        case operationId = "operation_id"
        case mode
        case appleAuthorizationCode = "apple_authorization_code"
    }
}

enum AccountDeletionLocalState {
    static func clear(profileId: UUID) {
        let defaults = UserDefaults.standard
        let profileToken = profileId.uuidString.lowercased()
        let accountPrefixes = [
            "fitup.messaging.", "fitup.metricSync.", "fitup.dailyTotals.",
            "fitup.intradayTick.", "fitup.hkDiagnostics.", "home.hero.snapshot.",
            "home.battle.stats.", "home.daily.battle.margins.", "stats.page.snapshot.",
            "fitup.statsStepsToday.", "fitup.onboardingComplete.",
            "fitup.postAuthDisplayNameComplete.", "fitup.healthKitOnboardingPromptCompleted.",
        ]
        for key in defaults.dictionaryRepresentation().keys {
            let lower = key.lowercased()
            if lower.contains(profileToken) || accountPrefixes.contains(where: lower.hasPrefix) {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.removeObject(forKey: "fitup.notification.inbox.items")
    }
}
