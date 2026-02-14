// MARK: - Services/DirectoryScanner.swift
import Foundation
import UniformTypeIdentifiers

final class DirectoryScanner {
    private let keys: [URLResourceKey] = [
        .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey
    ]

    func scan(at root: URL,
              textOnly: Bool,
              followSymlinks: Bool,
              includeHidden: Bool,
              exclusion: ExclusionMatcher,
              maxFileSizeBytes: Int64?,
              progress: @escaping (_ scannedCount: Int, _ totalUnknown: Int?) async -> Void
    ) async throws -> ([FileCandidate], Int) {
        var candidates: [FileCandidate] = []
        var skipped = 0
        let fm = FileManager.default
        
        var options: FileManager.DirectoryEnumerationOptions = []
        if !includeHidden {
            options.insert(.skipsHiddenFiles)
        }

        guard let en = fm.enumerator(at: root, includingPropertiesForKeys: keys, options: options, errorHandler: { (_, _) -> Bool in true }) else {
            return ([], 0)
        }

        var count = 0
        while let obj = en.nextObject() {
            try Task.checkCancellation()
            if let url = obj as? URL {
                count += 1
                if let vals = try? url.resourceValues(forKeys: Set(keys)) {
                    if vals.isSymbolicLink == true && !followSymlinks { skipped += 1; continue }
                    guard vals.isRegularFile == true else { continue }

                    let name = url.lastPathComponent
                    if exclusion.matches(name) { skipped += 1; continue }
                    
                    // FIX 1: Variable name corrected from 'includeHiddenFiles' to 'includeHidden'
                    if !includeHidden && name == ".env" {
                        skipped += 1; continue
                    }

                    let uti = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier
                    let size = Int64(vals.fileSize ?? 0)
                    if let max = maxFileSizeBytes, size > max { skipped += 1; continue }

                    if textOnly {
                        if !UTTypeConformance.isText(uti: uti, url: url) { skipped += 1; continue }
                    }

                    candidates.append(FileCandidate(url: url, size: size, typeIdentifier: uti))
                }
                if count % 400 == 0 { await progress(count, nil) }
            }
        }

        candidates.sort { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }
        return (candidates, skipped)
    }

    // MARK: - FEATURE 1: Lightweight scanner for autocomplete
    func scanAllFileNames(at root: URL, includeHidden: Bool) async throws -> [String] {
        var names: [String] = []
        let fm = FileManager.default
        var options: FileManager.DirectoryEnumerationOptions = []
        if !includeHidden {
            options.insert(.skipsHiddenFiles)
        }

        guard let en = fm.enumerator(at: root,
                                     includingPropertiesForKeys: [.isRegularFileKey],
                                     options: options,
                                     errorHandler: { (_,_) -> Bool in true }) else {
            return []
        }

        // FIX 2: Replaced 'for case let' loop with 'while let' to satisfy concurrency requirements
        while let url = en.nextObject() as? URL {
            try Task.checkCancellation()
            if let isFile = try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isFile == true {
                names.append(url.lastPathComponent)
            }
        }
        
        return Array(Set(names)).sorted()
    }
}
