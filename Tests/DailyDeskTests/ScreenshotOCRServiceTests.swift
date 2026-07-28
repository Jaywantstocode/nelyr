import AppKit
import XCTest
@testable import Nelyr

@MainActor
final class ScreenshotOCRServiceTests: XCTestCase {
    func testInvalidImageIsRejected() async {
        do {
            _ = try await ScreenshotOCRService.shared.process(Data("not an image".utf8))
            XCTFail("Expected invalid image error")
        } catch {
            XCTAssertTrue(error is ScreenshotOCRError)
        }
    }

    func testRecognizesTextAndNormalizesImageToPNG() async throws {
        let image = NSImage(size: NSSize(width: 900, height: 180))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 900, height: 180).fill()
        ("DAILY DESK OCR 2026" as NSString).draw(
            at: NSPoint(x: 35, y: 55),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 56, weight: .bold),
                .foregroundColor: NSColor.black
            ]
        )
        image.unlockFocus()

        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let sourceData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let result = try await ScreenshotOCRService.shared.process(sourceData)

        XCTAssertTrue(result.pngData.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        XCTAssertTrue(result.recognizedText.uppercased().contains("DAILY DESK OCR 2026"))
    }
}
