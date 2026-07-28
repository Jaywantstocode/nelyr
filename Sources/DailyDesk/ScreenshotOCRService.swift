import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

struct ProcessedScreenshot: Equatable, Sendable {
    let pngData: Data
    let recognizedText: String
}

actor ScreenshotOCRService {
    static let shared = ScreenshotOCRService()

    func process(_ sourceData: Data) throws -> ProcessedScreenshot {
        guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ScreenshotOCRError.invalidImage
        }

        let pngData = try encodePNG(image)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ja-JP", "en-US"]

        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        try handler.perform([request])

        let observations = (request.results ?? []).sorted { lhs, rhs in
            let verticalDistance = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
            if verticalDistance > 0.015 {
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ProcessedScreenshot(pngData: pngData, recognizedText: text)
    }

    private func encodePNG(_ image: CGImage) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ScreenshotOCRError.couldNotEncodeImage
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ScreenshotOCRError.couldNotEncodeImage
        }
        return output as Data
    }
}

enum ScreenshotOCRError: LocalizedError {
    case invalidImage
    case couldNotEncodeImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "Nelyr could not read that image. Try PNG, JPEG, HEIC, or TIFF."
        case .couldNotEncodeImage:
            "Nelyr could not prepare that image for Obsidian."
        }
    }
}
