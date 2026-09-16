//
//  SupabaseProvider.swift
//  FitUp
//
//  Holds optional Supabase client after keys are loaded from Info.plist (via xcconfig).
//

import Combine
import Foundation
import Supabase

enum SupabaseProvider {
    static var client: SupabaseClient?
}

enum AppThirdPartyConfig {
    static func configureIfPossible() {
        if
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            SupabaseProvider.client = SupabaseClient(
                supabaseURL: url,
                supabaseKey: key.trimmingCharacters(in: .whitespacesAndNewlines)
            )
#if DEBUG
            print("FitUp: Supabase configured for \(url.host ?? url.absoluteString).")
#endif
        } else {
            SupabaseProvider.client = nil
#if DEBUG
            print("FitUp: Supabase not configured (missing SUPABASE_URL / SUPABASE_ANON_KEY in Info.plist).")
#endif
        }
    }
}
