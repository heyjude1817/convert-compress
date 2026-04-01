import Foundation

/// Context for resolving naming template placeholders.
struct NamingContext {
    let originalName: String    // Filename without extension
    let index: Int              // 1-based sequence number within the batch
    let width: Int?
    let height: Int?
    let targetExtension: String
}

/// Resolves a NamingTemplate pattern into a concrete filename.
struct NamingTemplateResolver {
    private static let placeholderRegex = try! NSRegularExpression(pattern: #"\{(\w+)(?::(\w+))?\}"#)
    private static let illegalCharacters = CharacterSet(charactersIn: "/:\0")

    /// Resolves the template with the given context, returning the filename stem (no extension).
    func resolve(template: NamingTemplate, context: NamingContext) -> String {
        let pattern = template.pattern
        let range = NSRange(pattern.startIndex..., in: pattern)
        var result = pattern

        let matches = Self.placeholderRegex.matches(in: pattern, range: range)
        // Process matches in reverse to preserve indices
        for match in matches.reversed() {
            guard let keyRange = Range(match.range(at: 1), in: pattern) else { continue }
            let key = String(pattern[keyRange])
            let format: String? = match.range(at: 2).location != NSNotFound
                ? Range(match.range(at: 2), in: pattern).map { String(pattern[$0]) }
                : nil
            let fullRange = Range(match.range, in: pattern)!

            let replacement = replacementValue(for: key, format: format, context: context)
            result.replaceSubrange(fullRange, with: replacement)
        }

        return sanitize(result)
    }

    /// Resolves filenames for a batch, detecting and fixing collisions.
    func resolveBatch(template: NamingTemplate, contexts: [NamingContext]) -> [String] {
        var results: [String] = []
        var usedNames: [String: Int] = [:]

        for context in contexts {
            var name = resolve(template: template, context: context)
            if let count = usedNames[name] {
                let suffix = count + 1
                usedNames[name] = suffix
                name = "\(name)_\(suffix)"
            } else {
                usedNames[name] = 0
            }
            results.append(name)
        }

        return results
    }

    // MARK: - Private

    private func replacementValue(for key: String, format: String?, context: NamingContext) -> String {
        switch key {
        case "name":
            return context.originalName
        case "n":
            if let fmt = format {
                return String(format: "%0\(fmt)d", context.index)
            }
            return "\(context.index)"
        case "date":
            return Self.dateFormatter.string(from: Date())
        case "datetime":
            return Self.dateTimeFormatter.string(from: Date())
        case "w":
            return context.width.map { "\($0)" } ?? "0"
        case "h":
            return context.height.map { "\($0)" } ?? "0"
        default:
            return "{\(key)}"
        }
    }

    private func sanitize(_ name: String) -> String {
        let cleaned = name.unicodeScalars.filter { !Self.illegalCharacters.contains($0) }
        let result = String(String.UnicodeScalarView(cleaned))
        return result.isEmpty ? "unnamed" : result
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f
    }()
}
