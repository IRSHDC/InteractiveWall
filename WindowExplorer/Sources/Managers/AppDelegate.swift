//  Copyright © 2018 JABT. All rights reserved.

import Cocoa
import PromiseKit

let style = Style()


struct Configuration {
    static let mapsPerScreen = 6
    static let touchScreenSize = CGSize(width: 4095, height: 2242.5)
    static let touchScreenRatio: CGFloat = 23.0 / 42.0
    static let loadMapsOnFirstScreen = false
}


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        WindowManager.instance.registerForNotifications()
        TouchManager.instance.setupTouchSocket()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

