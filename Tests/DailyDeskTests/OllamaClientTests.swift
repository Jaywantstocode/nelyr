import Foundation
import XCTest
@testable import Nelyr

final class OllamaClientTests: XCTestCase {
    override func setUp() {
        MockURLProtocol.handler = nil
    }

    func testStructuredEnrichmentDecodes() async throws {
        let client = makeClient { request in
            XCTAssertEqual(request.url?.path, "/api/chat")
            let requestBody = try XCTUnwrap(bodyData(from: request))
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
            let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
            XCTAssertEqual(messages.count, 8)
            XCTAssertTrue(messages.contains { $0["content"]?.contains("northern lights") == true })
            XCTAssertTrue(messages.contains { $0["content"]?.contains("Grandma") == true })
            let content = #"{"title":"Capture life","summary":"Save thoughts locally.","significance":"It preserves useful personal context.","type":"reflection","areas":["self"],"tags":["Local AI"],"next_step":""}"#
            let response = ["message": ["content": content]]
            return (200, try JSONSerialization.data(withJSONObject: response))
        }
        let result = try await client.enrich(text: "a thought", model: "test", customInstructions: "")
        XCTAssertEqual(result.title, "Capture life")
        XCTAssertEqual(result.type, .reflection)
        XCTAssertEqual(result.areas, [.selfArea])
        XCTAssertEqual(result.tags, ["Local AI"])
    }

    func testUnknownLifeTypeIsRejected() async throws {
        let client = makeClient { _ in
            let content = #"{"title":"Capture","summary":"Summary","significance":"Meaning","type":"dream","areas":["self"],"tags":[],"next_step":""}"#
            let response = ["message": ["content": content]]
            return (200, try JSONSerialization.data(withJSONObject: response))
        }

        do {
            _ = try await client.enrich(text: "a dream", model: "test", customInstructions: "")
            XCTFail("Expected invalid structured output")
        } catch {
            XCTAssertEqual(error as? OllamaError, .invalidStructuredOutput)
        }
    }

    func testEmbeddingResponseDecodes() async throws {
        let client = makeClient { request in
            XCTAssertEqual(request.url?.path, "/api/embed")
            return (200, Data(#"{"embeddings":[[1.0,0.0]]}"#.utf8))
        }
        let vectors = try await client.embeddings(for: ["hello"], model: "embed")
        XCTAssertEqual(vectors, [[1, 0]])
    }

    func testLightDictationCleanupUsesEditingPromptAndDecodesText() async throws {
        let client = makeClient { request in
            let requestBody = try XCTUnwrap(bodyData(from: request))
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
            let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
            XCTAssertTrue(messages.last?["content"]?.contains("Remove filler words") == true)
            XCTAssertTrue(messages.last?["content"]?.contains("what should I do?") == true)
            let response = ["message": ["content": #"{"text":"What should I do?"}"#]]
            return (200, try JSONSerialization.data(withJSONObject: response))
        }

        let result = try await client.cleanDictation(
            "Um what should I do?",
            mode: .light,
            model: "test"
        )

        XCTAssertEqual(result, "What should I do?")
    }

    func testRawDictationCleanupDoesNotContactOllama() async throws {
        let client = makeClient { _ in
            XCTFail("Raw cleanup should not make a request")
            return (500, Data())
        }

        let result = try await client.cleanDictation("そのまま", mode: .none, model: "test")

        XCTAssertEqual(result, "そのまま")
    }

    func testJapaneseCleanupPromptForbidsTranslation() async throws {
        let client = makeClient { request in
            let requestBody = try XCTUnwrap(bodyData(from: request))
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
            let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
            XCTAssertTrue(messages.contains { $0["content"]?.contains("明日は健太に電話") == true })
            XCTAssertTrue(messages.last?["content"]?.contains("SOURCE LANGUAGE CODE: ja") == true)
            XCTAssertTrue(messages.last?["content"]?.contains("Never translate") == true)
            let response = ["message": ["content": #"{"text":"今日は散歩に行きたい。"}"#]]
            return (200, try JSONSerialization.data(withJSONObject: response))
        }

        let result = try await client.cleanDictation(
            "えっと、今日は散歩に行きたい。",
            mode: .light,
            model: "test",
            detectedLanguage: "ja"
        )

        XCTAssertEqual(result, "今日は散歩に行きたい。")
    }

    func testCleanupIncludesAppContextDictionaryAndStyle() async throws {
        let client = makeClient { request in
            let data = try XCTUnwrap(bodyData(from: request))
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
            let prompt = try XCTUnwrap(messages.last?["content"])
            XCTAssertTrue(prompt.contains("WRITING CONTEXT: chat in Slack"))
            XCTAssertTrue(prompt.contains("Daily Desk"))
            XCTAssertTrue(prompt.contains("concise and casual"))
            return (200, try JSONSerialization.data(withJSONObject: ["message": ["content": #"{"text":"Hello"}"#]]))
        }
        _ = try await client.cleanDictation(
            "um hello",
            mode: .light,
            model: "test",
            context: DictationAppContext(appName: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap"),
            dictionary: ["Daily Desk"],
            customStyle: "concise and casual"
        )
    }

    func testTranslationAndSelectedTextEditingReturnReplacementText() async throws {
        let translationClient = makeClient { request in
            let data = try XCTUnwrap(bodyData(from: request))
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
            let prompt = try XCTUnwrap(messages.last?["content"])
            XCTAssertTrue(prompt.contains("Translate into English"))
            return (200, try JSONSerialization.data(withJSONObject: ["message": ["content": #"{"text":"Good morning"}"#]]))
        }
        let translated = try await translationClient.translateDictation("おはよう", target: .english, model: "test")

        let editClient = makeClient { request in
            let data = try XCTUnwrap(bodyData(from: request))
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
            let prompt = try XCTUnwrap(messages.last?["content"])
            XCTAssertTrue(prompt.contains("make this warmer"))
            XCTAssertTrue(prompt.contains("SELECTED TEXT"))
            return (200, try JSONSerialization.data(withJSONObject: ["message": ["content": #"{"text":"Hope you’re doing well."}"#]]))
        }
        let edited = try await editClient.editSelectedText(
            "Hello.",
            instruction: "make this warmer",
            model: "test",
            context: DictationAppContext(appName: "Mail", bundleIdentifier: "com.apple.mail")
        )
        XCTAssertEqual(translated, "Good morning")
        XCTAssertEqual(edited, "Hope you’re doing well.")
    }

    func testLanguageGuardRejectsJapaneseToEnglishTranslation() {
        XCTAssertFalse(DictationLanguageGuard.accepts(
            cleaned: "I want to take a walk today.",
            source: "今日は散歩に行きたい。",
            detectedLanguage: "ja"
        ))
        XCTAssertTrue(DictationLanguageGuard.accepts(
            cleaned: "今日は散歩に行きたい。",
            source: "えっと、今日は散歩に行きたい。",
            detectedLanguage: "ja"
        ))
    }

    private func makeClient(
        handler: @escaping @Sendable (URLRequest) throws -> (Int, Data)
    ) -> OllamaClient {
        MockURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return OllamaClient(
            baseURL: URL(string: "http://127.0.0.1:11434")!,
            session: URLSession(configuration: configuration)
        )
    }
}

private func bodyData(from request: URLRequest) -> Data? {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let bufferSize = 4_096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
        let count = stream.read(buffer, maxLength: bufferSize)
        if count < 0 { return nil }
        if count == 0 { break }
        data.append(buffer, count: count)
    }
    return data
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
