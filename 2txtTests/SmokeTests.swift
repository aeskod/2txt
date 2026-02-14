import XCTest
import Foundation
import UniformTypeIdentifiers
@testable import _txt

private enum TestFS {
    static func withTempDirectory(_ body: (URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("2txt_tests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try await body(root)
    }

    static func writeText(_ text: String, to url: URL) throws {
        guard let data = text.data(using: .utf8) else {
            throw NSError(domain: "TestFS", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode UTF-8 test data"])
        }
        try data.write(to: url)
    }

    static func writeBinary(_ bytes: [UInt8], to url: URL) throws {
        try Data(bytes).write(to: url)
    }
}

final class SmokeTests: XCTestCase {
    func testSmokePasses() {
        XCTAssertTrue(true)
    }
}

final class TemplateEngineTests: XCTestCase {
    func testTemplateTokenSubstitutionAndDirSanitization() throws {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2024, month: 2, day: 3, hour: 4, minute: 5, second: 6))!
        let rendered = TemplateEngine.render(template: "{yyyy}-{MM}-{dd}_{HH}-{mm}-{ss}_{dir}.txt", directoryName: "my/folder", at: date)
        XCTAssertEqual(rendered, "2024-02-03_04-05-06_my-folder.txt")
    }
}

final class ExclusionMatcherTests: XCTestCase {
    func testExactModeMatchesOnlyExact() {
        let matcher = ExclusionMatcher(patternMode: .exact, rawText: "node_modules")
        XCTAssertTrue(matcher.matches("node_modules"))
        XCTAssertFalse(matcher.matches("node_modules_backup"))
    }

    func testGlobModeSupportsWildcards() {
        let matcher = ExclusionMatcher(patternMode: .glob, rawText: "*.log")
        XCTAssertTrue(matcher.matches("app.log"))
        XCTAssertFalse(matcher.matches("app.txt"))
    }

    func testRegexModeValidAndInvalidPatterns() {
        let matcher = ExclusionMatcher(patternMode: .regex, rawText: "^(foo|bar)$\n(")
        XCTAssertTrue(matcher.matches("foo"))
        XCTAssertFalse(matcher.matches("baz"))
    }
}

final class DirectoryScannerTests: XCTestCase {
    func testHiddenEnvExcludedWhenIncludeHiddenIsFalse() async throws {
        try await TestFS.withTempDirectory { root in
            let env = root.appendingPathComponent(".env")
            let txt = root.appendingPathComponent("visible.txt")
            try TestFS.writeText("secret", to: env)
            try TestFS.writeText("ok", to: txt)

            let scanner = DirectoryScanner()
            let matcher = ExclusionMatcher(patternMode: .glob, rawText: "")
            let (candidates, _) = try await scanner.scan(
                at: root,
                textOnly: false,
                followSymlinks: false,
                includeHidden: false,
                exclusion: matcher,
                maxFileSizeBytes: nil,
                progress: { _, _ in }
            )

            let names = candidates.map { $0.url.lastPathComponent }
            XCTAssertTrue(names.contains("visible.txt"))
            XCTAssertFalse(names.contains(".env"))
        }
    }

    func testMaxFileSizeFilteringWorks() async throws {
        try await TestFS.withTempDirectory { root in
            let small = root.appendingPathComponent("small.txt")
            let big = root.appendingPathComponent("big.txt")
            try TestFS.writeText("12345", to: small)
            try TestFS.writeText(String(repeating: "a", count: 2048), to: big)

            let scanner = DirectoryScanner()
            let matcher = ExclusionMatcher(patternMode: .glob, rawText: "")
            let (candidates, _) = try await scanner.scan(
                at: root,
                textOnly: false,
                followSymlinks: false,
                includeHidden: true,
                exclusion: matcher,
                maxFileSizeBytes: 100,
                progress: { _, _ in }
            )

            let names = Set(candidates.map { $0.url.lastPathComponent })
            XCTAssertEqual(names, ["small.txt"])
        }
    }

    func testDeterministicSortOrderAndSymlinkBehavior() async throws {
        try await TestFS.withTempDirectory { root in
            let a = root.appendingPathComponent("a.txt")
            let b = root.appendingPathComponent("b.txt")
            try TestFS.writeText("a", to: a)
            try TestFS.writeText("b", to: b)
            let link = root.appendingPathComponent("link_to_a")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: a)

            let scanner = DirectoryScanner()
            let matcher = ExclusionMatcher(patternMode: .glob, rawText: "")

            let (offCandidates, _) = try await scanner.scan(
                at: root,
                textOnly: false,
                followSymlinks: false,
                includeHidden: true,
                exclusion: matcher,
                maxFileSizeBytes: nil,
                progress: { _, _ in }
            )

            let (onCandidates, _) = try await scanner.scan(
                at: root,
                textOnly: false,
                followSymlinks: true,
                includeHidden: true,
                exclusion: matcher,
                maxFileSizeBytes: nil,
                progress: { _, _ in }
            )

            let offNames = offCandidates.map { $0.url.lastPathComponent }
            XCTAssertEqual(offNames, offNames.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
            XCTAssertGreaterThanOrEqual(onCandidates.count, offCandidates.count)
        }
    }
}

final class ConcatenatorTests: XCTestCase {
    func testConcatenationWritesRelativeHeadersAndPayload() async throws {
        try await TestFS.withTempDirectory { root in
            let file = root.appendingPathComponent("one.txt")
            try TestFS.writeText("payload", to: file)

            let candidate = FileCandidate(url: file, size: 7, typeIdentifier: UTType.plainText.identifier)
            let out = root.appendingPathComponent("out.txt")

            let concatenator = Concatenator()
            try await concatenator.concatenate(files: [candidate], to: out, from: root, progress: { _, _ in })
            try await concatenator.appendString("\nTAIL", to: out)

            let text = try String(contentsOf: out, encoding: .utf8)
            XCTAssertTrue(text.contains("// ===== File: ./one.txt ====="))
            XCTAssertTrue(text.contains("payload"))
            XCTAssertTrue(text.contains("TAIL"))
        }
    }
}

final class TreeBuilderTests: XCTestCase {
    func testTreeOutputContainsExpectedEntriesAndOrder() async throws {
        try await TestFS.withTempDirectory { root in
            let a = root.appendingPathComponent("a.txt")
            let b = root.appendingPathComponent("b.txt")
            try TestFS.writeText("a", to: a)
            try TestFS.writeText("b", to: b)

            let tree = try TreeBuilder().buildTree(at: root, showSizes: true, maxDepth: 2, followSymlinks: false)
            XCTAssertTrue(tree.contains("a.txt"))
            XCTAssertTrue(tree.contains("b.txt"))
            XCTAssertLessThan(tree.range(of: "a.txt")!.lowerBound, tree.range(of: "b.txt")!.lowerBound)
        }
    }
}

final class UTTypeConformanceTests: XCTestCase {
    func testTextAndBinaryDetection() async throws {
        try await TestFS.withTempDirectory { root in
            let textFile = root.appendingPathComponent("file.txt")
            let binaryFile = root.appendingPathComponent("file.bin")
            let emptyFile = root.appendingPathComponent("empty.bin")

            try TestFS.writeText("hello", to: textFile)
            try TestFS.writeBinary([0, 1, 2, 3], to: binaryFile)
            try Data().write(to: emptyFile)

            XCTAssertTrue(UTTypeConformance.isText(uti: UTType.plainText.identifier, url: textFile))
            XCTAssertFalse(UTTypeConformance.isText(uti: nil, url: binaryFile))
            XCTAssertFalse(UTTypeConformance.isText(uti: nil, url: emptyFile))
        }
    }
}

final class EndToEndIntegrationTests: XCTestCase {
    func testScanConcatenateAndAppendTreeEndToEnd() async throws {
        try await TestFS.withTempDirectory { root in
            let a = root.appendingPathComponent("a.txt")
            let b = root.appendingPathComponent("b.md")
            let ignored = root.appendingPathComponent("ignored.log")

            try TestFS.writeText("A", to: a)
            try TestFS.writeText("B", to: b)
            try TestFS.writeText("IGNORED", to: ignored)

            let scanner = DirectoryScanner()
            let matcher = ExclusionMatcher(patternMode: .glob, rawText: "*.log")
            let (candidates, _) = try await scanner.scan(
                at: root,
                textOnly: false,
                followSymlinks: false,
                includeHidden: true,
                exclusion: matcher,
                maxFileSizeBytes: nil,
                progress: { _, _ in }
            )

            XCTAssertEqual(candidates.count, 2)

            let out = root.appendingPathComponent("output.txt")
            let concatenator = Concatenator()
            try await concatenator.concatenate(files: candidates, to: out, from: root, progress: { _, _ in })

            let treeText = try TreeBuilder().buildTree(at: root, showSizes: false, maxDepth: nil, followSymlinks: false)
            try await concatenator.appendString("\n\n===== DIRECTORY TREE: \(root.path) =====\n\n" + treeText, to: out)

            let output = try String(contentsOf: out, encoding: .utf8)
            XCTAssertTrue(output.contains("// ===== File: ./a.txt ====="))
            XCTAssertTrue(output.contains("// ===== File: ./b.md ====="))
            XCTAssertFalse(output.contains("IGNORED"))
            XCTAssertTrue(output.contains("===== DIRECTORY TREE:"))
            XCTAssertTrue(output.contains(root.lastPathComponent))
        }
    }
}
