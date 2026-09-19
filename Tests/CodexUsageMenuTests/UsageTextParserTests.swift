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
}
