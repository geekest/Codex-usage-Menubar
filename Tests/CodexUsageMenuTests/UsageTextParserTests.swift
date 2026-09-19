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

    func testConvertsChineseRemainingPercent() {
        let snapshot = UsageTextParser.parse("5-hour limit 25% 剩余。Weekly limit 80% 剩余。")
        XCTAssertEqual(snapshot?.fiveHourPercent, 75)
        XCTAssertEqual(snapshot?.weeklyPercent, 20)
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
