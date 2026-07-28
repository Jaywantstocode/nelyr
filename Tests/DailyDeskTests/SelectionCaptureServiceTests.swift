import AppKit
import XCTest
@testable import Nelyr

final class SelectionCaptureServiceTests: XCTestCase {
    func testReadsAndTrimsModernPlainText() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString("  a thought worth keeping\n", forType: .string)

        XCTAssertEqual(SelectionTextReader.read(from: pasteboard), "a thought worth keeping")
    }

    func testReadsLegacyStringPasteboardType() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString(
            "日本語のメモ",
            forType: NSPasteboard.PasteboardType("NSStringPboardType")
        )

        XCTAssertEqual(SelectionTextReader.read(from: pasteboard), "日本語のメモ")
    }

    func testRejectsWhitespaceOnlySelection() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString(" \n\t ", forType: .string)

        XCTAssertNil(SelectionTextReader.read(from: pasteboard))
    }
}
