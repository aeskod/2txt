// MARK: - Services/TreeBuilder.swift
import Foundation

final class TreeBuilder {
    private struct Node { let name: String; let isDir: Bool; let size: Int64 }

    func buildTree(at root: URL, showSizes: Bool, maxDepth: Int?, followSymlinks: Bool) throws -> String {
        var out = ""
        out += root.lastPathComponent + "\n"
        // Create a Set to track visited paths
        var visited = Set<String>()
        try walk(root: root, prefix: "", depth: 0, maxDepth: maxDepth, showSizes: showSizes, followSymlinks: followSymlinks, into: &out, visited: &visited)
        return out
    }

    private func walk(root: URL, prefix: String, depth: Int, maxDepth: Int?, showSizes: Bool, followSymlinks: Bool, into out: inout String, visited: inout Set<String>) throws {
        if let max = maxDepth, depth >= max { return }
        
        // Cycle detection logic
        // Use canonical path if available to detect symlinks pointing to same physical dir
        let canonical = (try? root.resourceValues(forKeys: [.canonicalPathKey]).canonicalPath) ?? root.path
        if visited.contains(canonical) { return }
        visited.insert(canonical)

        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
        let contents = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        for (idx, url) in contents.enumerated() {
            let last = idx == contents.count - 1
            let branch = last ? "└── " : "├── "
            let childPrefix = prefix + (last ? "    " : "│   ")
            let vals = try url.resourceValues(forKeys: Set(keys))
            let isDir = vals.isDirectory == true
            let isLink = vals.isSymbolicLink == true
            let size = Int64(vals.fileSize ?? 0)
            var name = url.lastPathComponent
            if isLink && !followSymlinks { name += " @" }
            if showSizes && !isDir { name += " (\(size) B)" }
            out += prefix + branch + name + "\n"
            if isDir { try walk(root: url, prefix: childPrefix, depth: depth+1, maxDepth: maxDepth, showSizes: showSizes, followSymlinks: followSymlinks, into: &out, visited: &visited) }
        }
    }
}
