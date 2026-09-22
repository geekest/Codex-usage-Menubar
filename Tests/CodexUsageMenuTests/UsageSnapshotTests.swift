import XCTest
@testable import CodexUsageMenu

final class UsageSnapshotTests: XCTestCase {
    func testUsedModeKeepsStoredPercentages() {
        let mode = UsageDisplayMode.used

        XCTAssertEqual(mode.percent(from: 21), 21)
        XCTAssertEqual(mode.percent(from: 10), 10)
        XCTAssertEqual(
            mode.menuTitle(fiveHourUsedPercent: 21, weeklyUsedPercent: 10),
            "5h 已用 21% · W 已用 10%"
        )
        XCTAssertEqual(mode.detailTitle(period: "5 小时", usedPercent: 21), "5 小时已使用：21%")
        XCTAssertEqual(mode.toggleTitle, "显示剩余")
    }

    func testRemainingModeComplementsStoredPercentages() {
        let mode = UsageDisplayMode.remaining

        XCTAssertEqual(mode.percent(from: 21), 79)
        XCTAssertEqual(mode.percent(from: 10), 90)
        XCTAssertEqual(
            mode.menuTitle(fiveHourUsedPercent: 21, weeklyUsedPercent: 10),
            "5h 剩余 79% · W 剩余 90%"
        )
        XCTAssertEqual(mode.detailTitle(period: "5 小时", usedPercent: 21), "5 小时剩余：79%")
        XCTAssertEqual(mode.detailTitle(period: "每周", usedPercent: 10), "每周剩余：90%")
        XCTAssertEqual(mode.toggleTitle, "显示已使用")
    }

    func testRemainingModeHandlesBoundariesAndUnavailableValues() {
        let mode = UsageDisplayMode.remaining

        XCTAssertEqual(mode.percent(from: 0), 100)
        XCTAssertEqual(mode.percent(from: 100), 0)
        XCTAssertNil(mode.percent(from: nil))
        XCTAssertEqual(
            mode.menuTitle(fiveHourUsedPercent: nil, weeklyUsedPercent: nil),
            "5h 剩余 — · W 剩余 —"
        )
        XCTAssertEqual(mode.detailTitle(period: "每周", usedPercent: nil), "每周剩余：—")
    }

    func testNextAlternatesBetweenModes() {
        XCTAssertEqual(UsageDisplayMode.used.next, .remaining)
        XCTAssertEqual(UsageDisplayMode.remaining.next, .used)
    }
}
