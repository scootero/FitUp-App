//
//  TesterFeedbackRepository.swift
//  FitUp
//

import Foundation
import Supabase

struct TesterFeedbackRepository {
    func submit(
        message: String,
        userId: UUID,
        category: String,
        screenName: String?,
        context: [String: String]?
    ) async throws {
        guard let client = SupabaseProvider.client else {
            throw ProfileRepositoryError.supabaseNotConfigured
        }
        var props: [String: String] = [:]
        if let context {
            for (k, v) in context {
                if k.count <= 64, v.count <= 500 { props[k] = v }
            }
        }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        let row = FeedbackInsert(
            userId: userId,
            message: message,
            category: category,
            screenName: screenName,
            appVersion: version,
            buildNumber: build,
            context: props.isEmpty ? nil : props
        )
        try await client.from("tester_feedback").insert(row).execute()
    }
}

private struct FeedbackInsert: Encodable {
    let userId: UUID
    let message: String
    let category: String
    let screenName: String?
    let appVersion: String?
    let buildNumber: String?
    let context: [String: String]?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case message
        case category
        case screenName = "screen_name"
        case appVersion = "app_version"
        case buildNumber = "build_number"
        case context
    }
}
