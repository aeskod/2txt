// MARK: - Util/UTType+Text.swift
import UniformTypeIdentifiers
import Foundation

enum UTTypeConformance {
    static func isText(uti: String?, url: URL) -> Bool {
        if let uti, let ut = UTType(uti) {
            if ut.conforms(to: .text) { return true }
            // Treat source/markup as text
            if ut.conforms(to: .sourceCode) || ut.conforms(to: .html) { return true }
            // Common additional types
            if ut == .json || ut == .yaml || ut == .xml || ut == .plainText { return true }
            // Explicitly skip known binary families
            if ut.conforms(to: .image) || ut.conforms(to: .audiovisualContent) || ut.conforms(to: .archive) { return false }
        }
        // Fallback sniff: read first few KB and check for NUL bytes
        if let fh = try? FileHandle(forReadingFrom: url) {
            defer { try? fh.close() }
            let data = fh.readData(ofLength: 4096)
            if data.isEmpty {
                return false  // Matches original behavior for EOF/error (assume not text)
            }
            return !data.contains(0)
        }
        // If all other checks fail, return false
        return false
    }
}
