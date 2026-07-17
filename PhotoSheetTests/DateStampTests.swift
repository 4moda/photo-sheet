import XCTest
#if canImport(PhotoSheetCore)
@testable import PhotoSheetCore
#else
@testable import PhotoSheet
#endif

final class DateStampTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }

    func testQuartzDateFormat() {
        // ゼロ埋めしない・先頭にアポストロフィがクォーツデートの流儀
        XCTAssertEqual(DateStamp.text(for: date(2026, 7, 17)), "'26 7 17")
        XCTAssertEqual(DateStamp.text(for: date(1998, 12, 3)), "'98 12 3")
        XCTAssertEqual(DateStamp.text(for: date(2001, 1, 1)), "'01 1 1")
    }
}
