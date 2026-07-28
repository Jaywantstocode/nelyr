import Foundation

@MainActor
final class EmbeddingIndex {
    struct Entry: Codable {
        var modifiedAt: Date
        var title: String
        var linkName: String
        var embedding: [Float]
    }

    private var entries: [String: Entry] = [:]
    private let storageURL: URL

    init(storageURL: URL? = nil) {
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let directory = support.appendingPathComponent("DailyDesk", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.storageURL = directory.appendingPathComponent("idea-embeddings.json")
        }
        load()
    }

    func relatedIdeas(
        to queryVector: [Float],
        notes: [VaultNote],
        client: OllamaClient,
        model: String,
        limit: Int = 3
    ) async throws -> [RelatedIdea] {
        let activePaths = Set(notes.map { $0.fileURL.path })
        entries = entries.filter { activePaths.contains($0.key) }
        let changed = notes.filter { note in
            guard let entry = entries[note.fileURL.path] else { return true }
            return abs(entry.modifiedAt.timeIntervalSince(note.modifiedAt)) > 0.5
        }

        for batch in changed.chunked(into: 24) {
            let vectors = try await client.embeddings(for: batch.map(\.searchableText), model: model)
            for (note, vector) in zip(batch, vectors) {
                entries[note.fileURL.path] = Entry(
                    modifiedAt: note.modifiedAt,
                    title: note.title,
                    linkName: note.linkName,
                    embedding: vector
                )
            }
        }
        save()

        return entries.values
            .map { entry in
                RelatedIdea(
                    linkName: entry.linkName,
                    title: entry.title,
                    score: VectorMath.cosineSimilarity(queryVector, entry.embedding)
                )
            }
            .filter { $0.score >= 0.45 }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    func upsert(note: VaultNote, embedding: [Float]) {
        entries[note.fileURL.path] = Entry(
            modifiedAt: note.modifiedAt,
            title: note.title,
            linkName: note.linkName,
            embedding: embedding
        )
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
