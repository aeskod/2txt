// MARK: - SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: AppViewModel
    @State private var showExclusionHelp = false

    private var isMaxFileSizeEnabled: Binding<Bool> {
        Binding<Bool>(
            get: { vm.settings.maxFileSizeMB != nil },
            set: { isEnabled in
                vm.settings.maxFileSizeMB = isEnabled ? (vm.settings.maxFileSizeMB ?? 10) : nil
            }
        )
    }
    
    private var maxFileSizeBinding: Binding<Int> {
        Binding<Int>(
            get: { vm.settings.maxFileSizeMB ?? 10 },
            set: { vm.settings.maxFileSizeMB = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // MARK: - Default Output GroupBox (FIXED)
            GroupBox("Default Output") {
                VStack(alignment: .leading) {
                    Text("When a default directory is set, the app can save the output file without showing the 'Save As...' dialog every time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("Directory:")
                        
                        // Logic to show path from bookmark
                        let path: String = {
                            if let data = vm.settings.defaultOutputDirBookmark {
                                // FIX: Added 'var stale' and passed '&stale' to satisfy 'inout Bool' requirement
                                var stale = false
                                if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
                                    return url.path
                                }
                            }
                            return "Not Set"
                        }()
                        
                        Text(path)
                            .font(.callout).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Clear sets bookmark data to nil
                        Button("Clear") { vm.settings.defaultOutputDirBookmark = nil }
                            .disabled(vm.settings.defaultOutputDirBookmark == nil)
                        
                        Button("Choose…", action: vm.pickDefaultOutputDirectory)
                    }
                }
                .padding(8)
            }
            
            // MARK: - General File Processing GroupBox
            GroupBox("General File Processing") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Picker("File name exclusion mode:", selection: $vm.settings.patternMode) {
                            ForEach(PatternMode.allCases) { Text($0.rawValue.capitalized).tag($0) }
                        }.pickerStyle(.segmented)

                        Button(action: { showExclusionHelp = true }) {
                            Image(systemName: "info.circle")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showExclusionHelp, arrowEdge: .bottom) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Exclusion Modes Explained")
                                    .font(.headline)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Exact").fontWeight(.bold)
                                    Text("Matches the full file or folder name precisely.\nExample: `node_modules`")
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Glob").fontWeight(.bold)
                                    Text("Uses shell-style wildcards. `*` matches anything, `?` matches one character.\nExample: `*.log`")
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Regex").fontWeight(.bold)
                                    Text("Uses powerful regular expressions for complex patterns.\nExample: `^\\..+`")
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("------------------------------------------")
                                    Text("Learn more about Glob:")
                                    Text("https://www.ibm.com/docs/en/netcoolconfigmanager/6.4.2?topic=wildcards-glob-regular-expressions")
                                    Text("Learn more about Regex:")
                                    Text("https://www.geeksforgeeks.org/dsa/write-regular-expressions/")
                                }
                            }
                            .padding()
                            .frame(width: 320)
                        }
                    }
                    
                    Toggle("Include only plain text & source code files", isOn: $vm.settings.textOnly)
                    Toggle("Include hidden files (e.g. .gitignore)", isOn: $vm.settings.includeHiddenFiles)
                    Toggle("Follow symbolic links", isOn: $vm.settings.followSymlinks)
                    Divider()
                    Toggle("Limit the size of included files", isOn: isMaxFileSizeEnabled.animation())
                    if isMaxFileSizeEnabled.wrappedValue {
                        Stepper(value: maxFileSizeBinding, in: 1...2048) {
                            HStack {
                                Text("Max file size (MB):").frame(width: 140, alignment: .leading)
                                Text("\(maxFileSizeBinding.wrappedValue)").monospaced()
                            }
                        }.padding(.leading, 20)
                    }
                }.padding(8)
            }
        }
        .padding()
        .frame(width: 550)
    }
}
