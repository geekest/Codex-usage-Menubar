import XCTest
@testable import CodexUsageMenu

final class UsageTextParserTests: XCTestCase {
    func testObservesTrustedChatGPTPageWithoutDependingOnUsagePath() {
        let url = URL(string: "https://chatgpt.com/codex/settings/analysis")!

        XCTAssertTrue(UsageNavigationPolicy.shouldObserveUsage(in: url))
    }

    func testDoesNotObserveLookalikeChatGPTHost() {
        let url = URL(string: "https://notchatgpt.com/codex/settings/analysis")!

        XCTAssertFalse(UsageNavigationPolicy.shouldObserveUsage(in: url))
    }

    func testReadsUsagePageAfterLoginNavigationDoesNotMatchOriginalRequest() {
        let url = URL(string: "https://chatgpt.com/codex/settings/usage")!

        XCTAssertEqual(
            UsageNavigationPolicy.decision(for: url, matchesCurrentRequest: false),
            .readUsage
        )
    }

    func testParsesBothWindows() {
        let text = "Codex usage 5-hour limit 37% used. Weekly limit 62% used."
        let snapshot = UsageTextParser.parse(text)
        XCTAssertEqual(snapshot?.fiveHourPercent, 37)
        XCTAssertEqual(snapshot?.weeklyPercent, 62)
    }

    func testKeepsUnavailableWindowNil() {
        let text = "Weekly usage 18%"
        let snapshot = UsageTextParser.parse(text)
        XCTAssertNil(snapshot?.fiveHourPercent)
        XCTAssertEqual(snapshot?.weeklyPercent, 18)
    }

    func testParsesChineseUsageLabels() {
        let text = "5 小时使用限额 37% 已使用。每周使用限额 62% 已使用。"
        let snapshot = UsageTextParser.parse(text)
        XCTAssertEqual(snapshot?.fiveHourPercent, 37)
        XCTAssertEqual(snapshot?.weeklyPercent, 62)
    }

    func testConvertsChineseRemainingPercent() {
        let snapshot = UsageTextParser.parse("5-hour limit 25% 剩余。Weekly limit 80% 剩余。")
        XCTAssertEqual(snapshot?.fiveHourPercent, 75)
        XCTAssertEqual(snapshot?.weeklyPercent, 20)
    }

    func testParsesChineseUsagePageText() {
        let text = """
        余额
        Codex 和工作共用同一用量限额。
        5 小时使用限额
        70% 剩余
        重置时间：12:01
        每周使用限额
        95% 剩余
        重置时间：2026 年 9 月 28 日 7:01
        """

        let snapshot = UsageTextParser.parse(text)

        XCTAssertEqual(snapshot?.fiveHourPercent, 30)
        XCTAssertEqual(snapshot?.weeklyPercent, 5)
    }

    func testFallsBackToPercentBeforeLabel() {
        let snapshot = UsageTextParser.parse("25% remaining for the 5-hour limit")

        XCTAssertEqual(snapshot?.fiveHourPercent, 75)
    }

    func testConvertsEnglishRemainingPercent() {
        let snapshot = UsageTextParser.parse("5-hour limit 25% remaining. Weekly limit 80% remaining.")
        XCTAssertEqual(snapshot?.fiveHourPercent, 75)
        XCTAssertEqual(snapshot?.weeklyPercent, 20)
    }

    func testKeepsEnglishUsedPercent() {
        let snapshot = UsageTextParser.parse("5-hour limit 25% used. Weekly limit 80% used.")
        XCTAssertEqual(snapshot?.fiveHourPercent, 25)
        XCTAssertEqual(snapshot?.weeklyPercent, 80)
    }

    func testConvertsRemainingBoundaryPercentsOnce() {
        let snapshot = UsageTextParser.parse("5-hour limit 0% remaining. Weekly limit 100% remaining.")
        XCTAssertEqual(snapshot?.fiveHourPercent, 100)
        XCTAssertEqual(snapshot?.weeklyPercent, 0)
    }

    func testKeepsUsedBoundaryPercents() {
        let snapshot = UsageTextParser.parse("5-hour limit 0% used. Weekly limit 100% used.")
        XCTAssertEqual(snapshot?.fiveHourPercent, 0)
        XCTAssertEqual(snapshot?.weeklyPercent, 100)
    }
}
