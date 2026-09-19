import Foundation
import Supabase

enum ModerationReason: String, CaseIterable, Identifiable, Sendable {
    case harassmentBullying = "harassment_bullying"
    case hateOffensive = "hate_offensive"
    case sexualInappropriate = "sexual_inappropriate"
    case spam
    case threatSafety = "threat_safety"
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .harassmentBullying: "Harassment or bullying"
        case .hateOffensive: "Hate or offensive content"
        case .sexualInappropriate: "Sexual or inappropriate content"
        case .spam: "Spam"
        case .threatSafety: "Threat or safety concern"
        case .other: "Other"
        }
    }
}

struct BlockedUser: Decodable, Identifiable, Equatable, Sendable {
    let id: UUID
    let displayName: String
    let initials: String
    let blockedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case initials
        case blockedAt = "blocked_at"
    }
}

protocol ModerationServicing: Sendable {
    func block(userId: UUID) async throws
    func unblock(userId: UUID) async throws
    func loadBlockedUsers() async throws -> [BlockedUser]
    func report(userId: UUID, reason: ModerationReason) async throws
    func report(messageId: UUID, reason: ModerationReason) async throws
}

final class ModerationRepository: ModerationServicing, @unchecked Sendable {
    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw FriendshipRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    func block(userId: UUID) async throws {
        do { try await client.rpc("block_user", params: ["p_target_id": userId.uuidString]).execute() }
        catch { logFailure(action: "block", error: error); throw error }
    }

    func unblock(userId: UUID) async throws {
        do { try await client.rpc("unblock_user", params: ["p_target_id": userId.uuidString]).execute() }
        catch { logFailure(action: "unblock", error: error); throw error }
    }

    func loadBlockedUsers() async throws -> [BlockedUser] {
        let response: PostgrestResponse<[BlockedUser]> = try await client
            .rpc("get_my_blocked_users")
            .execute()
        return response.value
    }

    func report(userId: UUID, reason: ModerationReason) async throws {
        do {
            try await client.rpc(
                "report_user",
                params: ["p_target_id": userId.uuidString, "p_reason": reason.rawValue]
            ).execute()
        } catch { logFailure(action: "report_user", error: error); throw error }
    }

    func report(messageId: UUID, reason: ModerationReason) async throws {
        do {
            try await client.rpc(
                "report_message",
                params: ["p_message_id": messageId.uuidString, "p_reason": reason.rawValue]
            ).execute()
        } catch { logFailure(action: "report_message", error: error); throw error }
    }

    private func logFailure(action: String, error: Error) {
        let code = (error as? PostgrestError)?.code ?? "request_failed"
        AppLogger.log(
            category: "moderation",
            level: .warning,
            message: "moderation_operation_failed",
            metadata: ["action": action, "error_code": code]
        )
    }
}
