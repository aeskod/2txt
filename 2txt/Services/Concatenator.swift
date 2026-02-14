// MARK: - Services/Concatenator.swift
import Foundation

final class Concatenator {
    private let bufferSize = 128 * 1024

    // MARK: - FEATURE 3: Add 'sourceRoot' to generate relative paths
    func concatenate(files: [FileCandidate], to destination: URL, from sourceRoot: URL, progress: @escaping (_ filesDone: Int, _ writtenBytes: Int64) async -> Void) async throws {
        // Ensure parent exists
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Create/Truncate
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let out = try FileHandle(forWritingTo: destination)
        defer { try? out.close() }

        var totalWritten: Int64 = 0
        var done = 0
        let newline = "\n".data(using: .utf8)!

        for f in files {
            try Task.checkCancellation()

            // MARK: - FIX: Safe relative path generation
            let rootPath = sourceRoot.path
            let filePath = f.url.path
            var relativePath = filePath
            
            // Strictly remove the root path prefix only
            if filePath.hasPrefix(rootPath) {
                relativePath = String(filePath.dropFirst(rootPath.count))
            }

            // Ensure consistent leading slash for display
            if !relativePath.hasPrefix("/") { relativePath = "/" + relativePath }

            // Construct the header
            let headerPath = ".\(relativePath)"
            let header = "// ===== File: \(headerPath) =====\n".data(using: .utf8)!
            try writeSync(out, header)
            totalWritten += Int64(header.count)


            let inFH = try FileHandle(forReadingFrom: f.url)
            defer { try? inFH.close() }  // Ensure close even on error/cancellation

            while let data = try inFH.read(upToCount: bufferSize) {
                try Task.checkCancellation()
                if data.isEmpty { break }
                try writeSync(out, data)
                totalWritten += Int64(data.count)
            }

            // Separate files with a single newline
            try writeSync(out, newline)
            totalWritten += Int64(newline.count)

            done += 1
            if done % 20 == 0 { await progress(done, totalWritten) }
        }
        await progress(done, totalWritten)
    }

    func appendString(_ string: String, to destination: URL) async throws {
        let out = try FileHandle(forWritingTo: destination)
        defer { try? out.close() }
        try out.seekToEnd()
        if let data = string.data(using: .utf8) { try writeSync(out, data) }
    }

    private func writeSync(_ fh: FileHandle, _ data: Data) throws {
        try fh.write(contentsOf: data)
    }
}
