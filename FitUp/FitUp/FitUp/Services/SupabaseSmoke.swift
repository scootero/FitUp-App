//
//  SupabaseSmoke.swift
//  FitUp
//
//  Slice 0: minimal connectivity check against `profiles`.
//

import Foundation
import Supabase

enum SupabaseSmoke {
    enum Result {
        case skippedNoClient
        case success
        case failure(String)
    }

    static func runProfilesProbe() async -> Result {
        guard let client = SupabaseProvider.client else {
            return .skippedNoClient
        }
        do {
            _ = try await client.from("profiles").select().limit(1).execute()
            return .success
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
