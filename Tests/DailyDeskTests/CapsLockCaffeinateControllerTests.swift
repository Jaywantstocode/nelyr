import AppKit
import XCTest
@testable import Nelyr

@MainActor
final class CapsLockCaffeinateControllerTests: XCTestCase {
    func testCapsLockStartsAndStopsCaffeinate() {
        let controller = CapsLockCaffeinateController.shared
        controller.stop()

        controller.synchronize(modifierFlags: [.capsLock])
        XCTAssertTrue(controller.isActive)

        controller.synchronize(modifierFlags: [])
        XCTAssertFalse(controller.isActive)
    }
}
