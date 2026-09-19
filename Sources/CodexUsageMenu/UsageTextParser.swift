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
        let textRange = NSRange(text.startIndex..., in: text)
        guard let percentRegex = try? NSRegularExpression(pattern: "(?<!\\d)(\\d{1,3})\\s*%") else {
            return nil
        }

        let percents = percentRegex.matches(in: text, range: textRange).compactMap { match -> (Int, NSRange)? in
            guard let percentRange = Range(match.range(at: 1), in: text),
                  let percent = Int(text[percentRange]), (0...100).contains(percent) else {
                return nil
            }
            return (percent, match.range)
        }

        for label in labels {
            guard let labelRegex = try? NSRegularExpression(pattern: "(?i)\(label)") else { continue }
            for labelMatch in labelRegex.matches(in: text, range: textRange) {
                if let nearest = percents
                    .map({ percent in
                        let distance = max(
                            max(
                                labelMatch.range.location - NSMaxRange(percent.1),
                                percent.1.location - NSMaxRange(labelMatch.range)
                            ),
                            0
                        )
                        let isAfterLabel = percent.1.location >= NSMaxRange(labelMatch.range)
                        return (percent.0, distance, isAfterLabel)
                    })
                    .filter({ $0.1 <= 140 })
                    .min(by: { left, right in
                        left.1 == right.1 ? left.2 && !right.2 : left.1 < right.1
                    }) {
                    return nearest.0
                }
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
