//
//  Profile.swift
//  FitUp
//
//  Minimal app profile model used by Slice 1 auth/session flow.
//

import Foundation

struct Profile: Codable, Equatable, Identifiable {
    let id: UUID
    let authUserId: UUID
    let displayName: String
    let initials: String
    let avatarURL: String?
    let subscriptionTier: String
    let timezone: String?
    // Added in Slice 9 schema — nil means default (true) for users created before the column.
    let notificationsEnabled: Bool?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case authUserId = "auth_user_id"
        case displayName = "display_name"
        case initials
        case avatarURL = "avatar_url"
        case subscriptionTier = "subscription_tier"
        case timezone
        case notificationsEnabled = "notifications_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
