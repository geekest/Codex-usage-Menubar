import Foundation

enum UsageTextParser {
    static func parse(_ text: String, now: Date = .now) -> UsageSnapshot? {
        let normalized = text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        let fiveHour = firstPercent(near: ["5[\\s-]*hour", "5h", "five-hour"], in: normalized)
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
                return usedPercent(percent, near: match.range(at: 1), in: text)
            }
        }
        return nil
    }

    private static func usedPercent(_ percent: Int, near percentRange: NSRange, in text: String) -> Int {
        let textLength = (text as NSString).length
        let contextRange = NSRange(
            location: max(0, percentRange.location - 32),
            length: min(textLength, NSMaxRange(percentRange) + 32) - max(0, percentRange.location - 32)
        )
        let pattern = "(?i)remaining|used|剩余|已使用"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return percent }

        let qualifiers = regex.matches(in: text, range: contextRange)
        let nearest = qualifiers.min { distance(from: $0.range, to: percentRange) < distance(from: $1.range, to: percentRange) }
        guard let nearest, let range = Range(nearest.range, in: text) else { return percent }

        let qualifier = text[range].lowercased()
        return qualifier == "remaining" || qualifier == "剩余" ? 100 - percent : percent
    }

    private static func distance(from qualifierRange: NSRange, to percentRange: NSRange) -> Int {
        if NSMaxRange(qualifierRange) <= percentRange.location {
            return percentRange.location - NSMaxRange(qualifierRange)
        }
        if NSMaxRange(percentRange) <= qualifierRange.location {
            return qualifierRange.location - NSMaxRange(percentRange)
        }
        return 0
    }
}
