// MARK: - ContentView.swift
import SwiftUI
import AppKit // Required for NSWorkspace

struct ContentView: View {
    @ObservedObject var vm: AppViewModel
    @FocusState private var isExclusionEditorFocused: Bool
    @Environment(\.openWindow) var openWindow

    var body: some View {
        VStack(spacing: 16) {
            
            // MARK: - 1. Source & Naming Block
            GroupBox("Source & Naming") {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                    
                    // First Row: Source
                    GridRow {
                        Text("Source Directory:")
                        Text(vm.sourceDirectory?.path(percentEncoded: false) ?? "Not selected")
                            .font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Choose…", action: vm.pickSourceDirectory)
                    }
                    
                    // Second Row: Output Name
                    GridRow {
                        Text("Output Name:")
                        TextField("Template", text: $vm.settings.template)
                            .textFieldStyle(.roundedBorder)
                        
                        Menu {
                            if !vm.settings.customTemplates.isEmpty {
                                Section("Select Preset") {
                                    ForEach(vm.settings.customTemplates) { preset in
                                        Button(preset.value) {
                                            vm.settings.template = preset.value
                                        }
                                    }
                                }
                                Divider()
                            }
                            Button("Manage Presets…") {
                                openWindow(id: "manage-presets")
                            }
                        } label: {
                            Text("Presets")
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    
                    // Third Row: Preview
                    GridRow {
                        Text("Preview: \(vm.livePreviewName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .gridCellColumns(3)
                    }
                }
                .padding(8)
            }

            // MARK: - 2. Search & Filtering Block
            GroupBox("Search & Filtering") {
                HSplitView {
                    // Left Side: Exclusions
                    VStack(alignment: .leading, spacing: 5) {
                        Text("File & Folder Name Exclusions")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        FocusableTextEditor(text: $vm.settings.exclusionText) { command in
                            guard !vm.exclusionSuggestions.isEmpty else { return false }
                            switch command {
                            case .up:
                                vm.moveSuggestionSelection(down: false)
                                return true
                            case .down:
                                vm.moveSuggestionSelection(down: true)
                                return true
                            case .enter, .tab:
                                if vm.suggestionSelectionIndex != nil {
                                    vm.confirmSuggestionSelection()
                                    return true
                                }
                                return false
                            }
                        }
                        .focused($isExclusionEditorFocused)
                        .onChange(of: vm.settings.exclusionText) { _, _ in vm.updateExclusionSuggestions() }
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    }
                    .padding(8)
                    .frame(minWidth: 300)

                    // Right Side: Suggestions
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Suggestions")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    if isExclusionEditorFocused && !vm.exclusionSuggestions.isEmpty {
                                        ForEach(Array(vm.exclusionSuggestions.enumerated()), id: \.offset) { index, suggestion in
                                            Button(action: { vm.selectExclusionSuggestion(suggestion) }) {
                                                Text(suggestion)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            .background(index == vm.suggestionSelectionIndex ? Color.accentColor.opacity(0.8) : Color.clear)
                                            .foregroundColor(index == vm.suggestionSelectionIndex ? .white : .primary)
                                            .id(index)

                                            if suggestion != vm.exclusionSuggestions.last {
                                                Divider()
                                            }
                                        }
                                    } else if isExclusionEditorFocused && vm.exclusionSuggestions.isEmpty && !vm.settings.exclusionText.isEmpty {
                                        // Optional: Empty state feedback
                                        Text("No matches found")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .padding(10)
                                    }
                                }
                                .onChange(of: vm.suggestionSelectionIndex) { _, newIndex in
                                    if let index = newIndex {
                                        proxy.scrollTo(index)
                                    }
                                }
                            }
                        }
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    }
                    .padding(8)
                    .frame(minWidth: 200)
                }
                .frame(height: 160)
            }

            // MARK: - 3. Output Options
            GroupBox("Output Options") {
                VStack(alignment: .leading) {
                    Toggle("Append directory tree to the end of the file", isOn: $vm.settings.appendTree)
                    if vm.settings.appendTree {
                        Toggle("Show file sizes in the directory tree", isOn: $vm.settings.treeShowSizes).padding(.leading, 20)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            // MARK: - 4. Process Control
            GroupBox("Process Control") {
                VStack(spacing: 10) {
                    HStack {
                        ProgressView(value: vm.progressFraction) {
                            Text(vm.progressDetail).font(.callout)
                        }
                        
                        if vm.isRunning {
                            Button("Cancel", role: .destructive, action: vm.cancel)
                        }
                        
                        Button("Save") { vm.run(overrideDestination: true) }
                            .keyboardShortcut(.defaultAction)
                            .disabled(vm.isRunning || vm.sourceDirectory == nil)
                    }
                    
                    if !vm.resultSummary.isEmpty {
                        // MARK: - FEATURE: Success Message & Go To File Button
                        HStack(spacing: 8) {
                            Text(vm.resultSummary)
                                .font(.caption).foregroundStyle(.secondary)
                            
                            if let url = vm.lastOutputURL {
                                Button("Go To File") {
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                }
                                .buttonStyle(.link)
                                .controlSize(.small)
                            }
                        }
                    }
                    
                    if let err = vm.errorMessage {
                        Text(err)
                            .font(.caption).foregroundStyle(.red)
                    }
                }.padding(8)
            }
        }
        .padding()
    }
}
