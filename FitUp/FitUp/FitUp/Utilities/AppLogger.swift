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

    /// Fire-and-forget log line (never throws to callers).
    static func log(
        category: String,
        level: LogLevel = .info,
        message: String,
        userId: UUID? = nil,
        metadata: [String: String]? = nil
    ) {
        let line = "[\(category)] \(message)"
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
