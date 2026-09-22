import Foundation

struct UsageSnapshot: Equatable {
    // 两个百分比均表示对应周期内已使用的额度。
    let fiveHourPercent: Int?
    let weeklyPercent: Int?
    let updatedAt: Date
}

enum UsageDisplayMode: Equatable {
    case used
    case remaining

    var toggleTitle: String {
        switch self {
        case .used: return "显示剩余"
        case .remaining: return "显示已使用"
        }
    }

    var next: UsageDisplayMode {
        self == .used ? .remaining : .used
    }

    func menuTitle(fiveHourUsedPercent: Int?, weeklyUsedPercent: Int?) -> String {
        "5h \(shortLabel) \(display(percent(from: fiveHourUsedPercent))) · "
            + "W \(shortLabel) \(display(percent(from: weeklyUsedPercent)))"
    }

    func detailTitle(period: String, usedPercent: Int?) -> String {
        "\(period)\(detailLabel)：\(display(percent(from: usedPercent)))"
    }

    func percent(from usedPercent: Int?) -> Int? {
        guard let usedPercent else { return nil }
        return self == .used ? usedPercent : 100 - usedPercent
    }

    private var shortLabel: String {
        switch self {
        case .used: return "已用"
        case .remaining: return "剩余"
        }
    }

    private var detailLabel: String {
        switch self {
        case .used: return "已使用"
        case .remaining: return "剩余"
        }
    }

    private func display(_ value: Int?) -> String {
        value.map { "\($0)%" } ?? "—"
    }
}

enum UsageState: Equatable {
    case idle
    case refreshing
    case needsLogin
    case ready
    case failed(String)

    var description: String {
        switch self {
        case .idle: return "等待首次刷新"
        case .refreshing: return "正在刷新"
        case .needsLogin: return "需要登录 ChatGPT"
        case .ready: return "已同步"
        case .failed(let message): return message
        }
    }
}
