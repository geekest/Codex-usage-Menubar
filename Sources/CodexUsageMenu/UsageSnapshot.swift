import Foundation

struct UsageSnapshot: Equatable {
    // 两个百分比均表示对应周期内已使用的额度。
    let fiveHourPercent: Int?
    let weeklyPercent: Int?
    let updatedAt: Date

    var menuTitle: String {
        "5h 已用 \(display(fiveHourPercent)) · W 已用 \(display(weeklyPercent))"
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
