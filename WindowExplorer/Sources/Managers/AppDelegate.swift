//  Copyright © 2018 JABT. All rights reserved.

import Cocoa
import PromiseKit

let style = Style()


struct Configuration {
    static let mapsPerScreen = 4
    static let numberOfScreens = 1
    static let touchScreenSize = CGSize(width: 21564, height: 12116)
    static let loadMapsOnFirstScreen = false
}

struct ShellCommands {
    static let openLaunchPath = "/usr/bin/open"
    static let openMapsBaseArg = ["-n", "-a", "/Users/spencerperkins/Library/Developer/Xcode/DerivedData/MapExplorer-dttmkubbxpmqnkgcnmtskfqjhfbq/Build/Products/Debug/MapExplorer-macOS.app", "--args"]
    static let killallLaunchPath = "/usr/bin/killall"
    static let killallArgs = ["MapExplorer-macOS"]
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        WindowManager.instance.registerForNotifications()
        TouchManager.instance.setupTouchSocket()
        launchMapExplorer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Insert code here to tear down your application
        killallMaps()
        print("terminate")
    }
}

private func launchMapExplorer() {
    let firstScreen = Configuration.loadMapsOnFirstScreen ? 0 : 1

    for screen in firstScreen ... Configuration.numberOfScreens {
        for map in 0 ..< Configuration.mapsPerScreen {
            let args = ShellCommands.openMapsBaseArg + [String(screen), String(map)]
            shell(ShellCommands.openLaunchPath, args)
        }
    }
}

private func killallMaps() {
    shell(ShellCommands.killallLaunchPath, ShellCommands.killallArgs)
}

private func shell(_ launchPath: String, _ args: [String])  {
    let task = Process()
    task.launchPath = launchPath
    task.arguments = args
    task.launch()
    task.waitUntilExit()
}
