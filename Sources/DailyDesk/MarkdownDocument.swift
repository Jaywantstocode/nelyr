import Foundation

enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case unorderedList([String])
    case orderedList([String])
    case quote(String)
    case code(language: String?, text: String)
    case table(headers: [String], rows: [[String]])
    case rule
}

enum MarkdownBlockParser {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                index += 1
                var codeLines: [String] = []
                while index < lines.count,
                      !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                blocks.append(.code(
                    language: language.isEmpty ? nil : language,
                    text: codeLines.joined(separator: "\n")
                ))
                continue
            }

            if let heading = heading(from: trimmed) {
                blocks.append(.heading(level: heading.level, text: heading.text))
                index += 1
                continue
            }

            if isRule(trimmed) {
                blocks.append(.rule)
                index += 1
                continue
            }

            if index + 1 < lines.count,
               isTableRow(trimmed),
               isTableSeparator(lines[index + 1]) {
                let headers = tableCells(from: trimmed)
                index += 2
                var rows: [[String]] = []
                while index < lines.count, isTableRow(lines[index]) {
                    rows.append(tableCells(from: lines[index]))
                    index += 1
                }
                blocks.append(.table(headers: headers, rows: rows))
                continue
            }

            if unorderedItem(from: trimmed) != nil {
                var items: [String] = []
                while index < lines.count,
                      let item = unorderedItem(from: lines[index].trimmingCharacters(in: .whitespaces)) {
                    items.append(item)
                    index += 1
                }
                blocks.append(.unorderedList(items))
                continue
            }

            if orderedItem(from: trimmed) != nil {
                var items: [String] = []
                while index < lines.count,
                      let item = orderedItem(from: lines[index].trimmingCharacters(in: .whitespaces)) {
                    items.append(item)
                    index += 1
                }
                blocks.append(.orderedList(items))
                continue
            }

            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard candidate.hasPrefix(">") else { break }
                    quoteLines.append(String(candidate.dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(.quote(quoteLines.joined(separator: " ")))
                continue
            }

            var paragraphLines: [String] = []
            while index < lines.count {
                let candidate = lines[index]
                let candidateTrimmed = candidate.trimmingCharacters(in: .whitespaces)
                guard !candidateTrimmed.isEmpty else { break }
                if !paragraphLines.isEmpty, startsBlock(lines: lines, at: index) { break }
                paragraphLines.append(String(candidate.drop(while: { $0 == " " || $0 == "\t" })))
                index += 1
            }
            if !paragraphLines.isEmpty {
                blocks.append(.paragraph(joinParagraphLines(paragraphLines)))
            }
        }

        return blocks
    }

    private static func startsBlock(lines: [String], at index: Int) -> Bool {
        let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("```") || heading(from: trimmed) != nil || isRule(trimmed) {
            return true
        }
        if unorderedItem(from: trimmed) != nil || orderedItem(from: trimmed) != nil || trimmed.hasPrefix(">") {
            return true
        }
        return index + 1 < lines.count && isTableRow(trimmed) && isTableSeparator(lines[index + 1])
    }

    private static func heading(from line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix { $0 == "#" }
        guard !hashes.isEmpty, hashes.count <= 6 else { return nil }
        let remainder = line.dropFirst(hashes.count)
        guard remainder.first == " " else { return nil }
        return (hashes.count, String(remainder.dropFirst()).trimmingCharacters(in: .whitespaces))
    }

    private static func unorderedItem(from line: String) -> String? {
        guard line.count >= 2 else { return nil }
        let prefixes = ["- ", "* ", "+ "]
        guard let prefix = prefixes.first(where: line.hasPrefix) else { return nil }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }

    private static func orderedItem(from line: String) -> String? {
        guard let markerEnd = line.firstIndex(where: { $0 == "." || $0 == ")" }) else { return nil }
        let number = line[..<markerEnd]
        guard !number.isEmpty, number.allSatisfy(\.isNumber) else { return nil }
        let afterMarker = line.index(after: markerEnd)
        guard afterMarker < line.endIndex, line[afterMarker] == " " else { return nil }
        return String(line[line.index(after: afterMarker)...]).trimmingCharacters(in: .whitespaces)
    }

    private static func isRule(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        guard compact.count >= 3, let first = compact.first, first == "-" || first == "*" || first == "_" else {
            return false
        }
        return compact.allSatisfy { $0 == first }
    }

    private static func isTableRow(_ line: String) -> Bool {
        let cells = tableCells(from: line)
        return line.contains("|") && cells.count >= 2 && !line.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let cells = tableCells(from: line)
        guard cells.count >= 2 else { return false }
        return cells.allSatisfy { cell in
            let compact = cell.trimmingCharacters(in: CharacterSet(charactersIn: " :"))
            return compact.count >= 3 && compact.allSatisfy { $0 == "-" }
        }
    }

    private static func tableCells(from line: String) -> [String] {
        var value = line.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("|") { value.removeFirst() }
        if value.hasSuffix("|") { value.removeLast() }
        return value.split(separator: "|", omittingEmptySubsequences: false).map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
    }

    private static func joinParagraphLines(_ lines: [String]) -> String {
        var result = ""
        for line in lines {
            if result.isEmpty {
                result = line
            } else if result.hasSuffix("  ") {
                result.removeLast(2)
                result += "\n" + line
            } else {
                result += " " + line
            }
        }
        return result
    }
}
