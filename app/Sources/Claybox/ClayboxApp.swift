import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // never quit (and take the game down with us) while the game is running
        MainActor.assumeIsolated { !(model?.isPlaying ?? false) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { model?.shutdown() }
    }
}

@main
struct ClayboxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Claybox", id: "main") {
            RootView()
                .environmentObject(model)
                .onAppear {
                    delegate.model = model
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Disc or ISO…") { model.chooseDisc() }
                    .keyboardShortcut("o")
            }
            HelpCommands(model: model)
        }

        Window("Claybox Help", id: "help") {
            HelpView()
                .environmentObject(model)
        }
        .defaultSize(width: 880, height: 600)
    }
}
