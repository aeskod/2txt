// MARK: - Services/ExclusionMatcher.swift
import Foundation
#if canImport(Darwin)
import Darwin
#endif

struct ExclusionMatcher {
    let mode: PatternMode
    let patterns: [String]

    init(patternMode: PatternMode, rawText: String) {
        self.mode = patternMode
        self.patterns = rawText
            .split(whereSeparator: { $0 == "\n" || $0 == "\r" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func matches(_ fileName: String) -> Bool {
        guard !patterns.isEmpty else { return false }
        switch mode {
        case .exact:
            return patterns.contains { $0 == fileName }
        case .glob:
            return patterns.contains { pat in fnmatch(pat, fileName) }
        case .regex:
            return patterns.contains { pat in (try? NSRegularExpression(pattern: pat))?.firstMatch(in: fileName, range: NSRange(location: 0, length: fileName.utf16.count)) != nil }
        }
    }

    private func fnmatch(_ pattern: String, _ name: String) -> Bool {
        #if canImport(Darwin)
        return Darwin.fnmatch(pattern, name, 0) == 0
        #else
        return pattern == name
        #endif
    }
}
