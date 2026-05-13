//
//  FriendshipRepository.swift
//  FitUp
//
//  Reads/writes `friendships` (pending + accepted) with canonical (a_id, b_id), a_id < b_id.
//

import Foundation
import Supabase

struct FriendshipRow: Equatable, Sendable {
    let aId: UUID
    let bId: UUID
    let status: String
    let requestedBy: UUID
    let createdAt: Date?
    let acceptedAt: Date?
}

struct FriendListItem: Identifiable, Equatable {
    /// Stable id for list (peer profile id).
    var id: UUID { peerId }
    let peerId: UUID
    let displayName: String
    let initials: String
    let colorHex: String
    let rowType: RowType
    let relevantDate: Date?

    enum RowType: Equatable {
        case accepted
        case incomingRequest
        case outgoingRequest
    }
}

struct SuggestedOpponentItem: Identifiable, Equatable {
    var id: UUID { profileId }
    let profileId: UUID
    let displayName: String
    let initials: String
    let colorHex: String
}

/// Display fields from `profiles` for arbitrary peer ids (e.g. friend request banner, challenge prefill).
struct PeerProfileSummary: Equatable, Sendable {
    let displayName: String
    let initials: String
}

enum FriendshipRepositoryError: LocalizedError {
    case supabaseNotConfigured
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .supabaseNotConfigured: return "Not signed in."
        case .unexpectedResponse: return "Could not load friends."
        }
    }
}

/// Resolved relationship with a single peer; matches `FriendListItem` semantics.
enum PeerFriendshipPhase: Equatable, Sendable {
    case unknown
    case none
    case incomingPending
    case outgoingPending
    case accepted
}

final class FriendshipRepository {
    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw FriendshipRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    private let leaderboard = LeaderboardRepository()
    private static let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Pair helper (must match database `a_id < b_id`)

    static func orderedPair(_ u: UUID, _ v: UUID) -> (UUID, UUID) {
        u.uuidString < v.uuidString ? (u, v) : (v, u)
    }

    // MARK: - Public

    /// All friendship rows the current user is part of.
    func fetchFriendshipRows(currentProfileId: UUID) async throws -> [FriendshipRow] {
        let c = try client
        let response = try await c
            .from("friendships")
            .select("a_id, b_id, status, requested_by, created_at, accepted_at")
            .or("a_id.eq.\(currentProfileId.uuidString),b_id.eq.\(currentProfileId.uuidString)")
            .execute()
        return jsonRows(from: response.data).compactMap { parseFriendshipRow($0) }
    }

    func friendshipPhase(currentProfileId: UUID, peerProfileId: UUID) async throws -> PeerFriendshipPhase {
        if currentProfileId == peerProfileId { return .none }
        let rows = try await fetchFriendshipRows(currentProfileId: currentProfileId)
        for row in rows {
            let peer = row.aId == currentProfileId ? row.bId : row.aId
            guard peer == peerProfileId else { continue }
            switch row.status {
            case "accepted":
                return .accepted
            case "pending":
                return row.requestedBy == currentProfileId ? .outgoingPending : .incomingPending
            default:
                break
            }
        }
        return .none
    }

    /// Send a pending request to `peerId` (must not be self).
    func sendFriendRequest(from currentProfileId: UUID, to peerId: UUID) async throws {
        guard currentProfileId != peerId else { return }
        let (a, b) = Self.orderedPair(currentProfileId, peerId)
        let c = try client
        let body = FriendshipInsert(
            aId: a,
            bId: b,
            status: "pending",
            requestedBy: currentProfileId
        )
        try await c
            .from("friendships")
            .insert(body)
            .execute()
    }

    /// Accept a pending request for the given canonical pair.
    func acceptRequest(aId: UUID, bId: UUID) async throws {
        let c = try client
        let now = Self.isoString(from: Date())
        let patch = FriendshipAcceptPatch(status: "accepted", acceptedAt: now)
        try await c
            .from("friendships")
            .update(patch)
            .eq("a_id", value: aId.uuidString)
            .eq("b_id", value: bId.uuidString)
            .eq("status", value: "pending")
            .execute()
    }

    /// Remove friendship or cancel/decline (delete row).
    func deleteFriendship(aId: UUID, bId: UUID) async throws {
        let c = try client
        try await c
            .from("friendships")
            .delete()
            .eq("a_id", value: aId.uuidString)
            .eq("b_id", value: bId.uuidString)
            .execute()
    }

    /// Builds UI rows: accepted friends, incoming, outgoing, and suggested opponents.
    func loadFriendListState(currentProfile: Profile) async throws -> (
        items: [FriendListItem],
        suggestions: [SuggestedOpponentItem]
    ) {
        let c = try client
        let rows = try await fetchFriendshipRows(currentProfileId: currentProfile.id)
        let opponentIds = try await leaderboard.fetchOpponentProfileIds(currentUserId: currentProfile.id)

        var acceptedPeerIds: Set<UUID> = []
        var pendingIncoming: [(FriendshipRow, UUID)] = []
        var pendingOutgoing: [(FriendshipRow, UUID)] = []

        for row in rows {
            let peer: UUID = row.aId == currentProfile.id ? row.bId : row.aId
            switch row.status {
            case "accepted":
                acceptedPeerIds.insert(peer)
            case "pending":
                if row.requestedBy == currentProfile.id {
                    pendingOutgoing.append((row, peer))
                } else {
                    pendingIncoming.append((row, peer))
                }
            default:
                break
            }
        }

        let allPeerIds = Set(acceptedPeerIds
            .union(pendingIncoming.map(\.1))
            .union(pendingOutgoing.map(\.1)))
        let profiles = try await fetchProfilesMap(ids: Array(allPeerIds), client: c)

        var items: [FriendListItem] = []

        for (row, peer) in pendingIncoming.sorted(by: { ($0.0.createdAt ?? .distantPast) < ($1.0.createdAt ?? .distantPast) }) {
            let p = profiles[peer]
            items.append(
                FriendListItem(
                    peerId: peer,
                    displayName: p?.displayName ?? "Player",
                    initials: p?.initials ?? "PL",
                    colorHex: ProfileAccentColor.hex(for: peer),
                    rowType: .incomingRequest,
                    relevantDate: row.createdAt
                )
            )
        }
        for (row, peer) in pendingOutgoing.sorted(by: { ($0.0.createdAt ?? .distantPast) < ($1.0.createdAt ?? .distantPast) }) {
            let p = profiles[peer]
            items.append(
                FriendListItem(
                    peerId: peer,
                    displayName: p?.displayName ?? "Player",
                    initials: p?.initials ?? "PL",
                    colorHex: ProfileAccentColor.hex(for: peer),
                    rowType: .outgoingRequest,
                    relevantDate: row.createdAt
                )
            )
        }
        for peer in acceptedPeerIds.sorted(by: { $0.uuidString < $1.uuidString }) {
            let p = profiles[peer]
            let row = rows.first {
                $0.status == "accepted" && ($0.aId == peer || $0.bId == peer)
            }
            items.append(
                FriendListItem(
                    peerId: peer,
                    displayName: p?.displayName ?? "Player",
                    initials: p?.initials ?? "PL",
                    colorHex: ProfileAccentColor.hex(for: peer),
                    rowType: .accepted,
                    relevantDate: row?.acceptedAt ?? row?.createdAt
                )
            )
        }

        // Suggestions: past opponents with no friendship row (pending or accepted). After delete, they can reappear.
        var peersWithAnyRow: Set<UUID> = []
        for row in rows {
            let peer = row.aId == currentProfile.id ? row.bId : row.aId
            peersWithAnyRow.insert(peer)
        }
        let suggestionIds = opponentIds.subtracting(peersWithAnyRow)

        var suggestions: [SuggestedOpponentItem] = []
        if !suggestionIds.isEmpty {
            let sugProfiles = try await fetchProfilesMap(ids: Array(suggestionIds), client: c)
            for id in suggestionIds.sorted(by: { $0.uuidString < $1.uuidString }) {
                let p = sugProfiles[id]
                suggestions.append(
                    SuggestedOpponentItem(
                        profileId: id,
                        displayName: p?.displayName ?? "Player",
                        initials: p?.initials ?? "PL",
                        colorHex: ProfileAccentColor.hex(for: id)
                    )
                )
            }
        }

        return (items, suggestions)
    }

    /// Resolves a_ids / b_ids for a peer (for accept/remove).
    func canonicalPair(currentProfileId: UUID, peerId: UUID) -> (UUID, UUID) {
        Self.orderedPair(currentProfileId, peerId)
    }

    /// Batch-load `display_name` / `initials` from `profiles` by primary key `id`.
    func fetchPeerProfileSummaries(profileIds: [UUID]) async throws -> [UUID: PeerProfileSummary] {
        let c = try client
        let map = try await fetchProfilesMap(ids: profileIds, client: c)
        return map.mapValues { PeerProfileSummary(displayName: $0.displayName, initials: $0.initials) }
    }

    // MARK: - Private

    private struct ProfileShort {
        let displayName: String
        let initials: String
    }

    private func fetchProfilesMap(ids: [UUID], client: SupabaseClient) async throws -> [UUID: ProfileShort] {
        guard !ids.isEmpty else { return [:] }
        let unique = Array(Set(ids))
        let response = try await client
            .from("profiles")
            .select("id, display_name, initials")
            .in("id", values: unique)
            .execute()
        var map: [UUID: ProfileShort] = [:]
        for row in jsonRows(from: response.data) {
            guard let id = uuid(from: row["id"]) else { continue }
            let name = string(from: row["display_name"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Player"
            let ini = string(from: row["initials"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String(name.prefix(2)).uppercased()
            map[id] = ProfileShort(displayName: name.isEmpty ? "Player" : name, initials: ini.isEmpty ? "PL" : ini.uppercased())
        }
        return map
    }

    private func parseFriendshipRow(_ row: [String: Any]) -> FriendshipRow? {
        guard
            let a = uuid(from: row["a_id"]),
            let b = uuid(from: row["b_id"]),
            let status = string(from: row["status"]),
            let requestedBy = uuid(from: row["requested_by"])
        else { return nil }
        let created = Self.date(from: row["created_at"])
        let accepted = Self.date(from: row["accepted_at"])
        return FriendshipRow(
            aId: a,
            bId: b,
            status: status,
            requestedBy: requestedBy,
            createdAt: created,
            acceptedAt: accepted
        )
    }

    private static func date(from value: Any?) -> Date? {
        if let d = value as? Date { return d }
        if let s = value as? String {
            if let d = isoParser.date(from: s) { return d }
            let alt = ISO8601DateFormatter()
            alt.formatOptions = [.withInternetDateTime]
            return alt.date(from: s)
        }
        return nil
    }

    private static func isoString(from date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    private func jsonRows(from data: Data) -> [[String: Any]] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let rows = object as? [[String: Any]]
        else {
            return []
        }
        return rows
    }

    private func uuid(from value: Any?) -> UUID? {
        if let u = value as? UUID { return u }
        if let s = value as? String { return UUID(uuidString: s) }
        return nil
    }

    private func string(from value: Any?) -> String? { value as? String }
}

// MARK: - Encodable bodies

private struct FriendshipInsert: Encodable {
    let aId: UUID
    let bId: UUID
    let status: String
    let requestedBy: UUID

    enum CodingKeys: String, CodingKey {
        case aId = "a_id"
        case bId = "b_id"
        case status
        case requestedBy = "requested_by"
    }
}

private struct FriendshipAcceptPatch: Encodable {
    let status: String
    let acceptedAt: String

    enum CodingKeys: String, CodingKey {
        case status
        case acceptedAt = "accepted_at"
    }
}
