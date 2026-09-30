import SwiftUI

@main
struct LilimApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var browser = BrowserState(initialDirectory: launchDirectory)
    @State private var terminals = TerminalStore()

    private static var launchDirectory: URL? {
        guard let index = CommandLine.arguments.firstIndex(of: "--directory"),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return URL(fileURLWithPath: CommandLine.arguments[index + 1])
    }

    var body: some Scene {
        Window("Lilim", id: "workspace") {
            WorkspaceView(browser: browser, terminals: terminals)
                .tint(Theme.accent)
                .frame(minWidth: 1020, minHeight: 580)
                .onAppear { appDelegate.onTerminate = { terminals.terminateAll() } }
        }
        .defaultSize(width: 1420, height: 860)
        .windowToolbarStyle(.unifiedCompact)
        .commands { WorkspaceCommands(browser: browser, terminals: terminals) }
    }
}
