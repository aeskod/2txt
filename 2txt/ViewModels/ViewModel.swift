// MARK: - ViewModel.swift
import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    @Published var sourceDirectory: URL? = nil
    @Published var settings = AppSettings()

    @Published var livePreviewName: String = ""
    @Published var isRunning: Bool = false
    @Published var progressFraction: Double = 0
    @Published var progressDetail: String = ""
    @Published var resultSummary: String = ""
    @Published var errorMessage: String? = nil
    
    // MARK: - FEATURE: Track last output for "Go To File"
    @Published var lastOutputURL: URL? = nil

    @Published var allFileNames: [String] = []
    @Published var exclusionSuggestions: [String] = []
    
    @Published var suggestionSelectionIndex: Int? = nil
    
    private var task: Task<Void, Never>? = nil
    private var settingsSubscription: AnyCancellable?
    private var suggestionUpdateTask: Task<Void, Never>? = nil

    private let scanner = DirectoryScanner()
    private let treeBuilder = TreeBuilder()
    
    private var sanitizedDirectoryName: String {
        guard let dir = sourceDirectory else { return "folder" }
        let name = dir.lastPathComponent
        if name == "/" { return "root" }
        if name.isEmpty { return "folder" }
        return name
    }

    init() {
        loadSettings()
        updatePreview()
        
        settingsSubscription = $settings
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveSettings()
                self?.updatePreview()
            }
    }

    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "AppSettings"),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }
    }
    
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "AppSettings")
        }
    }

    func updatePreview() {
        livePreviewName = TemplateEngine.render(template: settings.template, directoryName: self.sanitizedDirectoryName, at: Date())
    }

    func pickSourceDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if panel.runModal() == .OK {
            sourceDirectory = panel.url
            updatePreview()
            scanForFileNames()
        }
    }
    
    func pickDefaultOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Default Output Directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                settings.defaultOutputDirBookmark = data
            } catch {
                errorMessage = "Failed to save permission: \(error.localizedDescription)"
            }
        }
    }

    func cancel() {
        task?.cancel()
    }
    
    private func scanForFileNames() {
        guard let src = sourceDirectory else { return }
        self.allFileNames = []
        self.exclusionSuggestions = []
        Task {
            let names = try? await scanner.scanAllFileNames(at: src, includeHidden: settings.includeHiddenFiles)
            await MainActor.run { self.allFileNames = names ?? [] }
        }
    }

    func updateExclusionSuggestions() {
        suggestionUpdateTask?.cancel()
        suggestionUpdateTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            let text = self.settings.exclusionText
            guard let lastLine = text.split(separator: "\n", omittingEmptySubsequences: false).last else {
                self.resetSuggestions(); return
            }
            let currentInput = String(lastLine).trimmingCharacters(in: .whitespaces)
            guard !currentInput.isEmpty else {
                self.resetSuggestions(); return
            }
            let filtered = self.allFileNames.filter {
                $0.localizedCaseInsensitiveContains(currentInput) && $0.lowercased() != currentInput.lowercased()
            }
            .sorted { s1, s2 in
                let inputLowercased = currentInput.lowercased()
                let s1IsPrefix = s1.lowercased().hasPrefix(inputLowercased)
                let s2IsPrefix = s2.lowercased().hasPrefix(inputLowercased)
                if s1IsPrefix != s2IsPrefix { return s1IsPrefix }
                return s1.localizedCaseInsensitiveCompare(s2) == .orderedAscending
            }
            self.exclusionSuggestions = filtered
            if self.exclusionSuggestions.isEmpty {
                self.suggestionSelectionIndex = nil
            } else {
                self.suggestionSelectionIndex = 0
            }
        }
    }

    func selectExclusionSuggestion(_ suggestion: String) {
        var lines = settings.exclusionText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard !lines.isEmpty else {
            settings.exclusionText = suggestion; return
        }
        lines[lines.count - 1] = suggestion
        settings.exclusionText = lines.joined(separator: "\n")
        resetSuggestions()
    }
    
    private func resetSuggestions() {
        self.exclusionSuggestions = []
        self.suggestionSelectionIndex = nil
    }

    func moveSuggestionSelection(down: Bool) {
        guard !exclusionSuggestions.isEmpty else {
            suggestionSelectionIndex = nil
            return
        }
        let maxIndex = exclusionSuggestions.count - 1
        var newIndex = suggestionSelectionIndex ?? (down ? -1 : maxIndex + 1)
        
        newIndex += down ? 1 : -1
        
        if newIndex > maxIndex { newIndex = 0 }
        if newIndex < 0 { newIndex = maxIndex }
        
        suggestionSelectionIndex = newIndex
    }

    func confirmSuggestionSelection() {
        guard let index = suggestionSelectionIndex, index < exclusionSuggestions.count else { return }
        selectExclusionSuggestion(exclusionSuggestions[index])
    }

    func run(overrideDestination: Bool = false) {
        guard let src = sourceDirectory else { errorMessage = "Select a source directory."; return }
        
        var destinationURL: URL?
        
        if overrideDestination || settings.defaultOutputDirBookmark == nil {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = TemplateEngine.render(template: settings.template, directoryName: self.sanitizedDirectoryName, at: Date())
            panel.canCreateDirectories = true
            panel.allowedContentTypes = [.text]
            
            if let data = settings.defaultOutputDirBookmark {
                var stale = false
                if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
                    panel.directoryURL = url
                }
            }
            
            guard panel.runModal() == .OK, let url = panel.url else {
                return
            }
            destinationURL = url
            
        } else if let bookmarkData = settings.defaultOutputDirBookmark {
            var stale = false
            do {
                let dirURL = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
                
                if stale {
                    errorMessage = "Directory permission is stale. Please re-select the default folder."
                    return
                }
                
                if dirURL.startAccessingSecurityScopedResource() {
                    dirURL.stopAccessingSecurityScopedResource()
                    
                    let fileName = TemplateEngine.render(template: settings.template, directoryName: self.sanitizedDirectoryName, at: Date())
                    destinationURL = dirURL.appendingPathComponent(fileName)
                    
                    _ = dirURL.startAccessingSecurityScopedResource()
                } else {
                    errorMessage = "Could not access default directory."
                    return
                }
            } catch {
                errorMessage = "Failed to resolve directory: \(error.localizedDescription)"
                return
            }
        }

        guard let dst = destinationURL else { errorMessage = "Could not determine an output destination."; return }

        startProcessing(source: src, destination: dst)
    }

    private func startProcessing(source src: URL, destination dst: URL) {
        saveSettings()
        resultSummary = ""
        errorMessage = nil
        lastOutputURL = nil // Reset previous link
        isRunning = true
        progressFraction = 0
        progressDetail = "Preparing…"

        let currentSettings = self.settings
        var exclusionText = currentSettings.exclusionText
        
        if !currentSettings.includeHiddenFiles && !exclusionText.contains(".env") {
            exclusionText += "\n.env"
        }
        
        let exclusion = ExclusionMatcher(patternMode: currentSettings.patternMode, rawText: exclusionText)

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let (candidates, skippedCount) = try await self.scanner.scan( at: src, textOnly: currentSettings.textOnly, followSymlinks: currentSettings.followSymlinks, includeHidden: currentSettings.includeHiddenFiles, exclusion: exclusion, maxFileSizeBytes: currentSettings.maxFileSizeMB.flatMap { Int64($0) * 1_048_576 }) { scanned, _ in
                    await MainActor.run { self.progressDetail = "Scanning… \(scanned)" }
                }

                let concatenator = Concatenator()
                var writtenBytes: Int64 = 0
                
                try await concatenator.concatenate(files: candidates, to: dst, from: src) { done, totalBytes in
                    writtenBytes = totalBytes
                    let frac = candidates.isEmpty ? 1.0 : Double(done) / Double(candidates.count)
                    await MainActor.run {
                        self.progressFraction = frac
                        self.progressDetail = "Writing (\(done)/\(candidates.count))…"
                    }
                }

                if currentSettings.appendTree {
                    let treeText = try self.treeBuilder.buildTree(at: src, showSizes: currentSettings.treeShowSizes, maxDepth: currentSettings.treeMaxDepth, followSymlinks: currentSettings.followSymlinks)
                    try await concatenator.appendString("\n\n===== DIRECTORY TREE: \(src.path) =====\n\n" + treeText, to: dst)
                }

                let byteFormatter = ByteCountFormatter()
                byteFormatter.countStyle = .file
                let sizeString = byteFormatter.string(fromByteCount: writtenBytes)

                await MainActor.run {
                    self.isRunning = false
                    self.progressFraction = 1
                    self.progressDetail = "Done"
                    self.resultSummary = "Success. Wrote \(candidates.count) files (\(sizeString)). Skipped \(skippedCount) items."
                    // MARK: - FIX: Set the last output URL so the button appears
                    self.lastOutputURL = dst
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isRunning = false
                    self.progressDetail = "Cancelled"
                }
            } catch {
                await MainActor.run {
                    self.isRunning = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
