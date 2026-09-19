import XCTest
@testable import CodexUsageMenu

final class UsageTextParserTests: XCTestCase {
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

    func testParsesChineseUsageLimits() {
        let text = "5 小时使用限额 100% 剩余\n每周使用限额 79% 剩余"
        let snapshot = UsageTextParser.parse(text)
        XCTAssertEqual(snapshot?.fiveHourPercent, 100)
        XCTAssertEqual(snapshot?.weeklyPercent, 79)
    }

    func testParsesPercentBeforeChineseLabel() {
        let text = "79% 剩余 每周使用限额"
        let snapshot = UsageTextParser.parse(text)
        XCTAssertNil(snapshot?.fiveHourPercent)
        XCTAssertEqual(snapshot?.weeklyPercent, 79)
    }

    func testRejectsOutOfRangeOrDistantPercentages() {
        XCTAssertNil(UsageTextParser.parse("每周使用限额 101% 剩余"))

        let distantPercent = "每周使用限额 " + String(repeating: "内容", count: 71) + " 42%"
        XCTAssertNil(UsageTextParser.parse(distantPercent))
    }
}
