//
//  AppLogger.swift
//  FitUp
//
//  Structured logs to Supabase `app_logs` when configured; otherwise os.Logger.
//

import Combine
import Foundation
import OSLog
import Supabase

enum LogLevel: String {
    case debug, info, warning, error
}

enum AppLogger {
    private static let osLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FitUp", category: "app")

    /// Supabase PostgREST errors often omit `code`/`detail` from `localizedDescription` (it is only `message`).
    /// Use this for `metadata` so Dashboard `app_logs` and Xcode match what Postgres returned.
    static func supabaseErrorMetadata(_ error: Error) -> [String: String] {
        var result: [String: String] = ["error": error.localizedDescription]
        let pg = error as? PostgrestError
        if let pg {
            result["pg_message"] = pg.message
            if let code = pg.code { result["pg_code"] = code }
            if let detail = pg.detail { result["pg_detail"] = detail }
            if let hint = pg.hint { result["pg_hint"] = hint }
        }
        return result
    }

    /// Per-value cap so huge fields (e.g. `hk_snapshot`) don’t flood the Xcode console.
    private static let maxConsoleMetadataValueLength = 800

    /// Fire-and-forget log line (never throws to callers).
    static func log(
        category: String,
        level: LogLevel = .info,
        message: String,
        userId: UUID? = nil,
        metadata: [String: String]? = nil
    ) {
        let line = consoleLine(category: category, message: message, userId: userId, metadata: metadata)
        switch level {
        case .debug: osLog.debug("\(line)")
        case .info: osLog.info("\(line)")
        case .warning: osLog.warning("\(line)")
        case .error: osLog.error("\(line)")
        }

        guard let client = SupabaseProvider.client else { return }

        Task {
            await insertRemote(
                client: client,
                userId: userId,
                category: category,
                level: level,
                message: message,
                metadata: metadata
            )
        }
    }

    private static func insertRemote(
        client: SupabaseClient,
        userId: UUID?,
        category: String,
        level: LogLevel,
        message: String,
        metadata: [String: String]?
    ) async {
        let row = AppLogInsert(
            userId: userId,
            category: category,
            level: level.rawValue,
            message: message,
            metadata: metadata
        )
        do {
            try await client.from("app_logs").insert(row).execute()
        } catch {
            osLog.error("app_logs insert failed: \(error.localizedDescription)")
        }
    }

    private static func consoleLine(
        category: String,
        message: String,
        userId: UUID?,
        metadata: [String: String]?
    ) -> String {
        var segments: [String] = ["[\(category)] \(message)"]
        if let userId {
            segments.append("userId=\(userId.uuidString)")
        }
        guard let metadata, !metadata.isEmpty else {
            return segments.joined(separator: " ")
        }
        let sorted = metadata.sorted { $0.key < $1.key }
        for pair in sorted {
            let value: String
            if pair.value.count > maxConsoleMetadataValueLength {
                value = String(pair.value.prefix(maxConsoleMetadataValueLength)) + "…(truncated)"
            } else {
                value = pair.value.replacingOccurrences(of: "\n", with: "\\n")
            }
            segments.append("\(pair.key)=\(value)")
        }
        return segments.joined(separator: " ")
    }
}

private struct AppLogInsert: Encodable {
    let userId: UUID?
    let category: String
    let level: String
    let message: String
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case category, level, message, metadata
    }
}
