//  Copyright © 2018 JABT. All rights reserved.

import Foundation
import AppKit
import MONode
import PromiseKit
import MacGestures


enum PresentationMode {
    case timeout
    case lock
}


final class WindowManager {
    static let instance = WindowManager()

    private(set) var mode = PresentationMode.timeout
    private(set) var windows = [NSWindow: GestureManager]()
    private var controllerForRecord = [RecordInfo: NSViewController]()

    private struct Keys {
        static let id = "id"
        static let app = "app"
        static let type = "type"
        static let position = "position"
    }


    // MARK: Init

    /// Use singleton instance
    private init() { }


    // MARK: API

    /// Must be done after application launches.
    func registerForNotifications() {
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(handleNotification(_:)), name: RecordNotification.display.name, object: nil)
    }

    func closeWindow(for controller: BaseViewController) {
        if let (window, _) = windows.first(where: { $0.value === controller.gestureManager }) {
            windows.removeValue(forKey: window)
            window.close()

            if let info = controllerForRecord.first(where: { $0.value == controller }) {
                controllerForRecord.removeValue(forKey: info.key)
            }
        }
    }

    @discardableResult
    func display(_ type: WindowType, at origin: CGPoint = .zero) -> NSViewController? {
        let window = WindowFactory.window(for: type, at: origin)

        if let controller = window.contentViewController {
            if let responder = controller as? GestureResponder {
                windows[window] = responder.gestureManager
            }

            return controller
        }

        return nil
    }

    /// If the controller is not draggable within the applications bounds, dismiss the window.
    func checkBounds(of controller: BaseViewController) {
        let applicationScreens = NSScreen.screens.dropFirst()
        let first = applicationScreens.first?.frame ?? .zero
        let applicationFrame = applicationScreens.reduce(first) { $0.union($1.frame) }
        if !controller.draggableInside(bounds: applicationFrame) {
            controller.close()
        }
    }

    func set(mode: PresentationMode) {
        self.mode = mode

        switch mode {
        case .timeout:
            resetAllWindowTimeouts()
        case .lock:
            break
        }
    }


    // MARK: Receiving Notifications

    @objc
    private func handleNotification(_ notification: NSNotification) {
        guard let info = notification.userInfo,
            let app = info[Keys.app] as? Int,
            let id = info[Keys.id] as? Int,
            let typeString = info[Keys.type] as? String,
            let type = RecordType(rawValue: typeString),
            let locationJSON = info[Keys.position] as? JSON,
            let location = CGPoint(json: locationJSON),
            let record = RecordManager.instance.record(for: type, id: id),
            let windowType = WindowType(for: record) else {
            return
        }

        let originX = location.x - windowType.size.width / 2
        let originY = max(style.windowMargins, location.y - windowType.size.height)
        let recordInfo = RecordInfo(id: record.id, app: app, type: record.type)
        display(recordInfo, for: windowType, at: CGPoint(x: originX, y: originY), app: app)
    }

    private func display(_ info: RecordInfo, for windowType: WindowType, at origin: CGPoint, app: Int) {
        if let controller = controllerForRecord[info] as? RecordViewController {
            controller.setWindow(origin: origin, animate: true)
        } else if let controller = controllerForRecord[info] as? RecordCollectionViewController {
            controller.setWindow(origin: origin, animate: true)
        } else if let controller = display(windowType, at: origin) {
            controllerForRecord[info] = controller
        }
    }

    private func resetAllWindowTimeouts() {
        for window in windows.keys {
            if let controller = window.contentViewController as? BaseViewController {
                controller.resetCloseWindowTimer()
            }
        }
    }
}
