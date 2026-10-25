import SwiftUI
import AppKit

// Claybox Help: a small built-in guide, opened from Help ▸ Claybox Help (⌘?) or the ? button.
// Plain, short answers. No web connection needed.

struct HelpTopic: Identifiable, Hashable {
    let id: String
    let symbol: String
    let title: String
    let sections: [HelpSection]
    static func == (a: HelpTopic, b: HelpTopic) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct HelpSection {
    let heading: String
    let text: String
}

enum HelpContent {
    static let topics: [HelpTopic] = [
        HelpTopic(id: "start", symbol: "flag", title: "Getting started", sections: [
            HelpSection(heading: "What you need",
                        text: "• A Mac with Apple silicon (M1 or later) and macOS 14 or later.\n• Your own original copy of The Neverhood: the Windows CD, or an ISO image made from it.\n• A few GB of free space: about 2 GB for the game and HD backgrounds, and about 3 GB more if you turn on HD videos."),
            HelpSection(heading: "The three steps",
                        text: "1. Add your game: drop the disc or ISO on the Claybox window, or click Choose file…\n2. Re-sculpt in HD: Claybox redraws the backgrounds on your Mac. You can skip this or play while it runs.\n3. Play: click Play."),
            HelpSection(heading: "Do I need the disc every time?",
                        text: "No. Claybox copies the game files to this Mac the first time. After that, you can put the disc away or delete the ISO."),
        ]),
        HelpTopic(id: "disc", symbol: "opticaldisc", title: "Your game disc", sections: [
            HelpSection(heading: "Which versions work?",
                        text: "The original Windows release of The Neverhood (1996) on CD, in English or other languages supported by ScummVM. Claybox checks the files before it goes on."),
            HelpSection(heading: "I don’t have a CD drive",
                        text: "Make an ISO image from your CD on any computer that has a drive, then drop the .iso file onto Claybox. On a Mac with a drive: open Disk Utility, choose File ▸ New Image ▸ Image from [the disc], and pick the “DVD/CD master” format. The .cdr file it makes works too."),
            HelpSection(heading: "“This doesn’t look like The Neverhood”",
                        text: "Claybox couldn’t find the game’s DATA folder. Check that it’s the original game disc and not a demo, a soundtrack CD or a different game. If you copied the files by hand, choose the folder that contains DATA."),
            HelpSection(heading: "Use a different disc",
                        text: "Click Change next to Disc on the main screen, then add the other disc or ISO."),
        ]),
        HelpTopic(id: "hd", symbol: "wand.and.stars", title: "HD and AI upscaling", sections: [
            HelpSection(heading: "How it works",
                        text: "Claybox uses Real-ESRGAN, an AI image model, to redraw the game’s pictures at twice the size. It runs on your Mac’s graphics chip. Nothing is uploaded and nothing from the game is downloaded."),
            HelpSection(heading: "HD backgrounds",
                        text: "All 259 scenes. Takes about 40 minutes on a recent Mac; older Macs take longer. You can play during it — scenes switch to HD as they’re finished. If you quit, it carries on where it stopped next time."),
            HelpSection(heading: "HD characters (optional)",
                        text: "Redraws the animated characters and objects, with smooth edges. Takes a few minutes up to about 20 minutes. Turn on HD characters in the Picture settings to start it."),
            HelpSection(heading: "HD videos (optional)",
                        text: "Redraws all 551 cutscenes. Takes about 40 minutes or more and needs about 3 GB of space. Turn on HD videos to start it. Switch it off and on again to continue after a pause."),
            HelpSection(heading: "Smooth picture",
                        text: "Softens anything that isn’t HD yet, so the game looks less blocky on a big screen. Turn it off if you prefer sharp, original pixels."),
            HelpSection(heading: "My Mac gets warm or the fans spin",
                        text: "That’s normal while HD is being made — the graphics chip is working hard. Keep laptops plugged in. Only one HD job runs at a time, and it stops when it’s done."),
            HelpSection(heading: "Re-make the HD files",
                        text: "Click Re-sculpt HD on the main screen. Use this if something looks wrong after an update."),
        ]),
        HelpTopic(id: "play", symbol: "gamecontroller", title: "Playing and saving", sections: [
            HelpSection(heading: "Controls",
                        text: "The Neverhood is played with the mouse only. Click where you want to walk, and click on things to use them."),
            HelpSection(heading: "Keys",
                        text: "• Esc — open the game’s menu (save, load, quit). In a cutscene, Esc skips it.\n• Option-Return — switch between full screen and a window.\n• Control-F5 — ScummVM’s menu, with save, load and options. On a Mac keyboard you may need to hold fn too.\n• ⌘Q — quit the game and go back to Claybox."),
            HelpSection(heading: "Saving",
                        text: "Save and load from the game’s own menu (Esc). Your saves are kept on this Mac. To back them up, use Help ▸ Show Saved Games and copy the folder."),
            HelpSection(heading: "Full screen",
                        text: "Turn on Full screen in the Picture settings before you click Play, or press Option-Return during the game."),
        ]),
        HelpTopic(id: "trouble", symbol: "wrench.and.screwdriver", title: "Troubleshooting", sections: [
            HelpSection(heading: "The game opens and closes right away",
                        text: "Claybox shows a message when this happens. Try turning off HD backgrounds and clicking Play again. If it still closes, use Help ▸ Show Engine Log and include that file when you report the problem."),
            HelpSection(heading: "HD stopped part-way",
                        text: "Quit Claybox and open it again — HD backgrounds carry on from where they stopped. For HD videos or characters, switch the setting off and on again."),
            HelpSection(heading: "Something looks wrong in HD",
                        text: "Turn off HD characters or HD videos to go back to the original for that part. A few small animations always stay in their original look; that’s expected."),
            HelpSection(heading: "Start over completely",
                        text: "Quit Claybox, use Help ▸ Show Claybox Folder, and move the Claybox folder to the Trash. Your saved games are inside it, so copy the saves folder first if you want to keep them."),
        ]),
        HelpTopic(id: "about", symbol: "heart", title: "About Claybox", sections: [
            HelpSection(heading: "A tribute",
                        text: "Claybox is a free tribute for The Neverhood’s 30th anniversary, made by Oxin Studio. It is not affiliated with the game’s creators or rights holders."),
            HelpSection(heading: "Who made this",
                        text: "Oxin Studio is a small independent studio in Calgary, Canada. We make Mac, iPhone and iPad apps that you buy once and own: no subscriptions, no accounts, and no data collection. Claybox is our thank-you to a game we grew up with."),
            HelpSection(heading: "Open source",
                        text: "Claybox is built on ScummVM and is free software under the GNU GPL. The source code is public. Thank you to the ScummVM team for the engine that makes this possible."),
            HelpSection(heading: "Privacy",
                        text: "Claybox doesn’t collect anything. There are no accounts, no analytics and no network connections during play or HD upscaling."),
        ]),
    ]
}

struct HelpView: View {
    @EnvironmentObject var model: AppModel
    @State private var selection: HelpTopic? = HelpContent.topics.first

    var body: some View {
        NavigationSplitView {
            List(HelpContent.topics, selection: $selection) { topic in
                Label(topic.title, systemImage: topic.symbol)
                    .tag(topic)
                    .padding(.vertical, 3)
            }
            .navigationSplitViewColumnWidth(210)
        } detail: {
            if let topic = selection {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(topic.title)
                            .font(Theme.display(34, .bold))
                            .foregroundStyle(Theme.title)
                        ForEach(Array(topic.sections.enumerated()), id: \.offset) { _, section in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(section.heading)
                                    .font(Theme.body(16, .semibold))
                                    .foregroundStyle(Theme.accentText)
                                Text(section.text)
                                    .font(Theme.body(14))
                                    .foregroundStyle(Theme.soft)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                        }
                        if topic.id == "trouble" || topic.id == "play" {
                            HStack(spacing: 10) {
                                Button("Show Saved Games") { model.revealSaves() }
                                Button("Show Engine Log") { model.revealEngineLog() }
                                Button("Show Claybox Folder") { model.revealSupportFolder() }
                            }
                            .padding(.top, 4)
                        }
                        if topic.id == "about" {
                            HStack(spacing: 10) {
                                Button("Claybox on oxinstudio.com") { NSWorkspace.shared.open(URL(string: "https://oxinstudio.com/apps/claybox/")!) }
                                Button("See our other apps") { NSWorkspace.shared.open(URL(string: "https://oxinstudio.com")!) }
                            }
                            .padding(.top, 4)
                        }
                        if topic.id == "start" {
                            Button("Show the Welcome Tour again") { model.showOnboarding = true }
                                .padding(.top, 4)
                        }
                    }
                    .padding(32)
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Theme.ground)
            }
        }
        .frame(minWidth: 760, minHeight: 520)
        .preferredColorScheme(.dark)
        .tint(Theme.clay)
    }
}

/// Help menu items, replacing the default "search help" item.
struct HelpCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Claybox Help") { openWindow(id: "help") }
                .keyboardShortcut("?", modifiers: .command)
            Button("Welcome Tour") { model.showOnboarding = true }
            Divider()
            Button("Show Saved Games") { model.revealSaves() }
            Button("Show Engine Log") { model.revealEngineLog() }
            Button("Show Claybox Folder") { model.revealSupportFolder() }
            Divider()
            Button("Oxin Studio Website") { NSWorkspace.shared.open(URL(string: "https://oxinstudio.com")!) }
            Button("ScummVM Website") { NSWorkspace.shared.open(URL(string: "https://www.scummvm.org")!) }
        }
    }
}

/// Small round "?" button for the corner of the main window.
struct HelpButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button { openWindow(id: "help") } label: {
            Image(systemName: "questionmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.soft)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.panel))
                .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Claybox Help (⌘?)")
        .accessibilityLabel("Claybox Help")
    }
}
