import Foundation

enum UsageTextParser {
    static func parse(_ text: String, now: Date = .now) -> UsageSnapshot? {
        let normalized = text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        let fiveHour = firstPercent(
            near: ["5[\\s-]*hour", "5h", "five-hour", "5\\s*小时(?:使用限额)?"],
            in: normalized
        )
        let weekly = firstPercent(
            near: ["weekly", "week", "7\\s*day", "seven-day", "每周(?:使用限额)?"],
            in: normalized
        )

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
                    .map({ percent -> (value: Int, range: NSRange, distance: Int, isAfterLabel: Bool) in
                        let percentRange = percent.1
                        let matchDistance = distance(from: labelMatch.range, to: percentRange)
                        let isAfterLabel = percentRange.location >= NSMaxRange(labelMatch.range)
                        return (percent.0, percentRange, matchDistance, isAfterLabel)
                    })
                    .filter({ $0.distance <= 140 })
                    .min(by: { left, right in
                        if left.distance == right.distance {
                            return left.isAfterLabel && !right.isAfterLabel
                        }
                        return left.distance < right.distance
                    }) {
                    return usedPercent(nearest.value, near: nearest.range, in: text)
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
