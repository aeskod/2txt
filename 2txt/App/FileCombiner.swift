// ===== File: ./2txt/App/FileCombinerApp.swift =====

// MARK: - FileCombinerApp.swift
import SwiftUI

@main
struct FileCombinerApp: App {
    // Create a single instance of the ViewModel to act as a source of truth.
    @StateObject private var vm = AppViewModel()

    var body: some Scene {
        WindowGroup {
            // The main view for core app functionality.
            ContentView(vm: vm)
                .frame(width: 860, height: 544) // Height can be smaller now
        }
        .windowResizability(.contentSize)

        // MARK: - FEATURE 1: Add a standard macOS Settings window.
        // This automatically creates a "Settings..." menu item and keyboard shortcut.
        Settings {
            SettingsView(vm: vm)
        }
        Window("Manage Presets", id: "manage-presets") {
                    ManagePresetsView(vm: vm)
                }
    }
}
