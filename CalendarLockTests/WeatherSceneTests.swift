import XCTest
@testable import CalendarLock

final class WeatherSceneTests: XCTestCase {
    func testWeatherCodesMapToScenes() {
        XCTAssertEqual(WeatherScene(code: 0), .clear)
        XCTAssertEqual(WeatherScene(code: 2), .partlyCloudy)
        XCTAssertEqual(WeatherScene(code: 3), .cloudy)
        XCTAssertEqual(WeatherScene(code: 45), .fog)
        XCTAssertEqual(WeatherScene(code: 61), .rain)
        XCTAssertEqual(WeatherScene(code: 81), .rain)
        XCTAssertEqual(WeatherScene(code: 73), .snow)
        XCTAssertEqual(WeatherScene(code: 95), .storm)
        XCTAssertEqual(WeatherScene(code: 1234), .cloudy, "Unknown codes fall back to clouds")
    }

    func testWeatherArtworkSurvivesSaving() throws {
        var settings = WallpaperSettings()
        settings.artwork = .weather
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(WallpaperSettings.self, from: data).artwork, .weather)
    }
}
