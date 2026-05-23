//
//  RecapMatchCard.swift
//  FitUp
//
//  Parsed from yesterday_recap push payload (recap_cards).
//

import Foundation

struct RecapMatchCard: Identifiable, Equatable, Codable {
    let matchId: UUID
    let rivalDisplayName: String
    let yesterdayWinner: String
    let yesterdayMargin: Int
    let yesterdayMarginLabel: String
    let seriesMy: Int
    let seriesTheir: Int
    let daysLeft: Int
    let isFinalDay: Bool
    let finalDayStanding: String
    let scoringMode: String
    let metricType: String

    var id: UUID { matchId }

    enum CodingKeys: String, CodingKey {
        case matchId = "match_id"
        case rivalDisplayName = "rival_display_name"
        case yesterdayWinner = "yesterday_winner"
        case yesterdayMargin = "yesterday_margin"
        case yesterdayMarginLabel = "yesterday_margin_label"
        case seriesMy = "series_my"
        case seriesTheir = "series_their"
        case daysLeft = "days_left"
        case isFinalDay = "is_final_day"
        case finalDayStanding = "final_day_standing"
        case scoringMode = "scoring_mode"
        case metricType = "metric_type"
    }

    var seriesLabel: String {
        "\(seriesMy)–\(seriesTheir)"
    }

    var daysLeftLabel: String {
        if isFinalDay { return "FINAL DAY" }
        if daysLeft == 1 { return "1 day left" }
        return "\(daysLeft) days left"
    }

    var yesterdaySummary: String? {
        switch yesterdayWinner {
        case "you":
            return "You won yesterday by \(yesterdayMargin) \(yesterdayMarginLabel)"
        case "opponent":
            return "\(rivalDisplayName) won yesterday by \(yesterdayMargin) \(yesterdayMarginLabel)"
        case "void":
            return "Yesterday was voided"
        default:
            return nil
        }
    }
}

enum RecapMatchCardParser {
    static func parse(from userInfo: [AnyHashable: Any]) -> [RecapMatchCard] {
        if let cards = decodeFromArray(userInfo["recap_cards"]) {
            return cards
        }
        if let json = userInfo["recap_cards"] as? String,
           let data = json.data(using: .utf8),
           let cards = try? JSONDecoder().decode([RecapMatchCard].self, from: data) {
            return cards
        }
        return []
    }

    private static func decodeFromArray(_ value: Any?) -> [RecapMatchCard]? {
        guard let arr = value as? [[AnyHashable: Any]] else { return nil }
        var cards: [RecapMatchCard] = []
        for dict in arr {
            guard let mid = dict["match_id"] as? String, let uuid = UUID(uuidString: mid) else { continue }
            cards.append(RecapMatchCard(
                matchId: uuid,
                rivalDisplayName: string(dict["rival_display_name"], fallback: "Opponent"),
                yesterdayWinner: string(dict["yesterday_winner"], fallback: "none"),
                yesterdayMargin: int(dict["yesterday_margin"]),
                yesterdayMarginLabel: string(dict["yesterday_margin_label"], fallback: "steps"),
                seriesMy: int(dict["series_my"]),
                seriesTheir: int(dict["series_their"]),
                daysLeft: int(dict["days_left"]),
                isFinalDay: bool(dict["is_final_day"]),
                finalDayStanding: string(dict["final_day_standing"], fallback: "tied"),
                scoringMode: string(dict["scoring_mode"], fallback: ""),
                metricType: string(dict["metric_type"], fallback: "steps")
            ))
        }
        return cards.isEmpty ? nil : cards
    }

    private static func string(_ value: Any?, fallback: String) -> String {
        (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (value as! String) : fallback
    }

    private static func int(_ value: Any?) -> Int {
        if let n = value as? Int { return n }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String, let n = Int(s) { return n }
        return 0
    }

    private static func bool(_ value: Any?) -> Bool {
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        return false
    }
}
