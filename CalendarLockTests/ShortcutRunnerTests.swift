import XCTest
@testable import CalendarLock

final class ShortcutRunnerTests: XCTestCase {
    func testRunURLEncodesNameAndCallbacks() throws {
        let url = try XCTUnwrap(ShortcutRunner.runURL(shortcutName: " Calendar Lock "))
        let text = url.absoluteString
        XCTAssertTrue(text.hasPrefix("shortcuts://x-callback-url/run-shortcut?"))
        XCTAssertTrue(text.contains("name=Calendar%20Lock"))
        XCTAssertTrue(text.contains("x-success=calendarlock%3A%2F%2Fshortcut%2Fdone"))
        XCTAssertNil(ShortcutRunner.runURL(shortcutName: "   "))
    }

    func testReadsCallbacks() throws {
        XCTAssertEqual(ShortcutRunner.result(from: try XCTUnwrap(URL(string: "calendarlock://shortcut/done"))), .done)
        XCTAssertEqual(ShortcutRunner.result(from: try XCTUnwrap(URL(string: "calendarlock://shortcut/error"))), .error)
        XCTAssertNil(ShortcutRunner.result(from: try XCTUnwrap(URL(string: "https://example.com/done"))))
    }
}
