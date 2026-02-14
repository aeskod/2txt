// MARK: - Models.swift
import Foundation
import UniformTypeIdentifiers

struct Preset: Codable, Identifiable, Hashable {
    var id = UUID()
    var value: String
}

enum PatternMode: String, Codable, CaseIterable, Identifiable { case exact, glob, regex; var id: String { rawValue } }

struct AppSettings: Codable {
    var patternMode: PatternMode = .glob
    var exclusionText: String = ""
    var textOnly: Bool = true
    var maxFileSizeMB: Int? = 10 // Optional limit; nil to disable
    var appendTree: Bool = true
    var treeShowSizes: Bool = true
    var treeMaxDepth: Int? = nil // nil = unlimited
    var followSymlinks: Bool = false
    var template: String = "{dd}.{MM}.{yy}@{HH}-{mm}-{ss}_{dir}.txt"
    var includeHiddenFiles: Bool = false
    var customTemplates: [Preset] = []
    
    // MARK: - FEATURE 2: Updated to store Security Scoped Bookmark Data
    var defaultOutputDirBookmark: Data? = nil
}

struct FileCandidate {
    let url: URL
    let size: Int64
    let typeIdentifier: String?
}
