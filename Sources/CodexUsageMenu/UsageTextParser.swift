import Foundation

enum UsageTextParser {
    static func parse(_ text: String, now: Date = .now) -> UsageSnapshot? {
        let normalized = text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        let fiveHour = firstPercent(near: ["5\\s*hour", "5h", "five-hour"], in: normalized)
        let weekly = firstPercent(near: ["weekly", "week", "7\\s*day", "seven-day"], in: normalized)

        guard fiveHour != nil || weekly != nil else { return nil }
        return UsageSnapshot(fiveHourPercent: fiveHour, weeklyPercent: weekly, updatedAt: now)
    }

    private static func firstPercent(near labels: [String], in text: String) -> Int? {
        for label in labels {
            let patterns = [
                "(?i)\(label)[^%]{0,140}?\\b(\\d{1,3})\\s*%",
                "(?i)\\b(\\d{1,3})\\s*%[^%]{0,140}?\(label)"
            ]
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(text.startIndex..., in: text)
                guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
                      let percentRange = Range(match.range(at: 1), in: text),
                      let percent = Int(text[percentRange]), (0...100).contains(percent) else { continue }
                return percent
            }
        }
        return nil
    }
}
