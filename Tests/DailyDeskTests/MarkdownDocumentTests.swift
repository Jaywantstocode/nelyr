import XCTest
@testable import Nelyr

final class MarkdownDocumentTests: XCTestCase {
    func testParsesResearchReportIntoReadableBlocks() {
        let markdown = """
        # Battery longevity

        ## Bottom line
        Staying near **80%** reduces high-voltage stress.

        - Lower peak voltage
        - Less time at full charge

        1. Enable a charge limit
        2. Avoid heat

        > Check the device maker's guidance.
        """

        XCTAssertEqual(MarkdownBlockParser.parse(markdown), [
            .heading(level: 1, text: "Battery longevity"),
            .heading(level: 2, text: "Bottom line"),
            .paragraph("Staying near **80%** reduces high-voltage stress."),
            .unorderedList(["Lower peak voltage", "Less time at full charge"]),
            .orderedList(["Enable a charge limit", "Avoid heat"]),
            .quote("Check the device maker's guidance.")
        ])
    }

    func testParsesTablesAndCodeWithoutFlatteningThem() {
        let markdown = """
        | Charge | Approx. cycles |
        | --- | ---: |
        | 100% | 500 |
        | 80% | 1,000 |

        ```swift
        let limit = 80
        print(limit)
        ```
        """

        XCTAssertEqual(MarkdownBlockParser.parse(markdown), [
            .table(
                headers: ["Charge", "Approx. cycles"],
                rows: [["100%", "500"], ["80%", "1,000"]]
            ),
            .code(language: "swift", text: "let limit = 80\nprint(limit)")
        ])
    }

    func testJoinsWrappedParagraphLinesButPreservesMarkdownHardBreaks() {
        let markdown = "First line\ncontinues here.\n\nHard break  \nnext line."

        XCTAssertEqual(MarkdownBlockParser.parse(markdown), [
            .paragraph("First line continues here."),
            .paragraph("Hard break\nnext line.")
        ])
    }
}
