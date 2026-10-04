import XCTest
import Photos
@testable import QuietApp

final class SensesTests: XCTestCase {
    @MainActor func testLivedPhotoFetchIsNewestFirstAndBounded() {
        let now = Date(timeIntervalSince1970: 10_000_000)
        let options = PhotoSense.recentFetchOptions(at: now)
        XCTAssertEqual(options.fetchLimit, 4)
        XCTAssertEqual(options.sortDescriptors?.count, 1)
        XCTAssertEqual(options.sortDescriptors?.first?.key, "creationDate")
        XCTAssertEqual(options.sortDescriptors?.first?.ascending, false)
    }

    @MainActor func testLivedPhotoFetchExcludesOldAndFutureAssets() throws {
        let now = Date(timeIntervalSince1970: 10_000_000)
        let predicate = try XCTUnwrap(PhotoSense.recentFetchOptions(at: now).predicate)
        func matches(_ date: Date) -> Bool {
            predicate.evaluate(with: ["creationDate": date as NSDate])
        }
        XCTAssertTrue(matches(now))
        XCTAssertTrue(matches(now.addingTimeInterval(-72 * 3600)))
        XCTAssertFalse(matches(now.addingTimeInterval(-72 * 3600 - 1)))
        XCTAssertFalse(matches(now.addingTimeInterval(1)))
    }
}
