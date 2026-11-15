import XCTest
@testable import CalendarLock

final class FontSizeTests: XCTestCase {
    func testFontPointsCarryOverFromOldTextSize() throws {
        let old = #"{"textSize":"large"}"#
        let settings = try JSONDecoder().decode(WallpaperSettings.self, from: Data(old.utf8))
        XCTAssertEqual(settings.fontPoints, WallpaperSettings.TextSize.large.points)
    }

    func testSavedFontPointsWin() throws {
        let saved = #"{"textSize":"large","fontPoints":11.5}"#
        let settings = try JSONDecoder().decode(WallpaperSettings.self, from: Data(saved.utf8))
        XCTAssertEqual(settings.fontPoints, 11.5)
    }
}
