import XCTest
@testable import CalendarLock

final class PhotoTests: XCTestCase {
    func testRotationMovesOnePhotoPerDay() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day1 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 6)))
        let day2 = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day1))
        let day4 = try XCTUnwrap(calendar.date(byAdding: .day, value: 3, to: day1))

        let first = try XCTUnwrap(PhotoStore.rotationIndex(count: 3, date: day1, calendar: calendar))
        XCTAssertEqual(PhotoStore.rotationIndex(count: 3, date: day2, calendar: calendar), (first + 1) % 3)
        XCTAssertEqual(PhotoStore.rotationIndex(count: 3, date: day4, calendar: calendar), first, "Back to the start after three days")
        XCTAssertNil(PhotoStore.rotationIndex(count: 0, date: day1, calendar: calendar))
        XCTAssertEqual(PhotoStore.rotationIndex(count: 1, date: day1, calendar: calendar), 0)
    }

    func testSameDayKeepsTheSamePhoto() throws {
        let calendar = Calendar(identifier: .gregorian)
        let morning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 6)))
        let evening = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 22)))
        XCTAssertEqual(PhotoStore.rotationIndex(count: 5, date: morning, calendar: calendar),
                       PhotoStore.rotationIndex(count: 5, date: evening, calendar: calendar))
    }

    func testPhotoFillCoversTheFrameAndCentersTheFocus() {
        let frame = CGSize(width: 100, height: 200)
        // A landscape photo: height decides the scale, width overflows.
        let image = CGSize(width: 400, height: 200)
        let centered = PhotoFill.frame(imageSize: image, in: frame, framing: PhotoEntry())
        XCTAssertEqual(centered.size, CGSize(width: 400, height: 200))
        XCTAssertEqual(centered.minX, -150, accuracy: 0.001)
        XCTAssertEqual(centered.minY, 0, accuracy: 0.001)

        var left = PhotoEntry()
        left.focusX = 0
        XCTAssertEqual(PhotoFill.frame(imageSize: image, in: frame, framing: left).minX, 0, accuracy: 0.001,
                       "The photo edge never moves inside the frame")

        var zoomed = PhotoEntry()
        zoomed.zoom = 2
        let rect = PhotoFill.frame(imageSize: image, in: frame, framing: zoomed)
        XCTAssertEqual(rect.size, CGSize(width: 800, height: 400))
        XCTAssertEqual(rect.minY, -100, accuracy: 0.001)
    }
}
