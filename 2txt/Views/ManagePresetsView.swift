// ===== File: ./Views/ManagePresetsView.swift =====
import SwiftUI

struct ManagePresetsView: View {
    @ObservedObject var vm: AppViewModel
    
    // Selection is now a Set of UUIDs, which is stable and correct.
    @State private var selection = Set<Preset.ID>()
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // A Table is the correct component for this UI. It handles selection,
            // alternating backgrounds, and editing bindings natively.
            Table($vm.settings.customTemplates, selection: $selection) {
                TableColumn("Preset") { $preset in
                    // The '$' creates a direct binding to the preset's value,
                    // making the text field editable inline.
                    TextField("Preset Name", text: $preset.value)
                        .textFieldStyle(.plain)
                }
            }
            // This modifier natively handles alternating row colors without any bugs.
            .alternatingRowBackgrounds(.automatic)
            
            HStack {
                Button(action: addPreset) { Image(systemName: "plus") }.help("Add a new preset")
                Button(action: removeSelectedPreset) { Image(systemName: "minus") }.disabled(selection.isEmpty).help("Remove the selected preset(s)")
                Spacer()
                Button("Clear All…", role: .destructive, action: clearAllPresets).disabled(vm.settings.customTemplates.isEmpty).help("Remove all presets")
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 450, height: 350)
    }

    // The logic is now updated to work with the `Preset` struct and UUIDs.
    private func addPreset() {
        var i = 1
        var newPresetValue: String
        repeat {
            newPresetValue = "Custom_Preset_\(i).txt"
            i += 1
        } while vm.settings.customTemplates.contains(where: { $0.value == newPresetValue })
        
        let newPreset = Preset(value: newPresetValue)
        vm.settings.customTemplates.append(newPreset)
        selection = [newPreset.id]
    }

    private func removeSelectedPreset() {
        // Find the index of the first item to be deleted to set the selection later.
        let firstIndex = vm.settings.customTemplates.firstIndex(where: { selection.contains($0.id) }) ?? 0
        
        // Remove all selected items by their stable ID.
        vm.settings.customTemplates.removeAll { selection.contains($0.id) }
        
        if vm.settings.customTemplates.isEmpty {
            selection = []
        } else {
            // Select the item that takes the place of the first deleted item.
            let newSelectionIndex = min(firstIndex, vm.settings.customTemplates.count - 1)
            selection = [vm.settings.customTemplates[newSelectionIndex].id]
        }
    }
    
    private func clearAllPresets() {
        let alert = NSAlert()
        alert.messageText = "Clear All Presets?"
        alert.informativeText = "Are you sure you want to delete all saved presets? This action cannot be undone."
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        if alert.runModal() == .alertFirstButtonReturn {
            vm.settings.customTemplates.removeAll()
        }
    }
}
