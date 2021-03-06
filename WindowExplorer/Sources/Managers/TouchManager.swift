//  Copyright © 2018 JABT. All rights reserved.

import Foundation
import MONode
import MacGestures


final class TouchManager: SocketManagerDelegate {
    static let instance = TouchManager()
    static let touchNetwork = NetworkConfiguration(broadcastHost: "0.0.0.0", nodePort: Configuration.touchPort)

    private var socketManager: SocketManager?
    private var managersForTouch = [Touch: (NSWindow, GestureManager)]()
    private var touchesForAppID = [Int: Set<Touch>]()
    private var touchNeedsUpdate = [Touch: Bool]()


    // MARK: Init

    private init() { }


    // MARK: API

    func setupTouchSocket() {
        socketManager = SocketManager(networkConfiguration: TouchManager.touchNetwork)
        socketManager?.delegate = self
    }


    // MARK: SocketManagerDelegate

    func handlePacket(_ packet: Packet) {
        guard let touch = Touch(from: packet), shouldSend(touch) else {
            return
        }

        // Convert the touch's position to the coordinates of the screen
        convert(touch, toScreen: touch.screen)

        // Pass the touch to the indicator view controller
        IndicatorViewController.instance?.displayIndicator(for: touch)

        // Check if the touch landed on a window, else notify the proper map application
        if let manager = manager(of: touch) {
            manager.handle(touch)
        } else if let (id, type) = appOwner(of: touch) {
            send(touch, to: id, type: type)
        } else {
            let (app, type) = calculateApp(for: touch)
            send(touch, to: app, type: type)
        }
    }

    func handleError(_ message: String) {
        print(message)
    }


    // MARK: Sending CF Messages

    /// Sends a touch to the map and updates the state of the touches for map dictionary
    private func send(_ touch: Touch, to app: Int, type: ApplicationType) {
        let portName = type.port(app: app)
        if let serverPort = CFMessagePortCreateRemote(nil, portName as CFString) {
            let touchData = touch.toData()
            CFMessagePortSendRequest(serverPort, 1, touchData as CFData, 1, 1, nil, nil)
        }
        updateTouchesForApp(with: touch, for: app)
    }


    // MARK: Helpers

    /// Calculates the manager and stores it locally for fast access to windows in the hierarchy
    private func manager(of touch: Touch) -> GestureManager? {
        switch touch.state {
        case .down:
            if let (window, manager) = calculateWindow(of: touch) {
                window.makeKeyAndOrderFront(self)
                managersForTouch[touch] = (window, manager)
                return manager
            }
        case .moved:
            if let (_, manager) = managersForTouch[touch] {
                return manager
            }
        case .up:
            if let (_, manager) = managersForTouch[touch] {
                managersForTouch.removeValue(forKey: touch)
                return manager
            }
        }

        return nil
    }

    /// Returns a gesture manager that owns the given touch, else nil.
    private func calculateWindow(of touch: Touch) -> (NSWindow, GestureManager)? {
        let windows = WindowManager.instance.windows.sorted(by: { $0.key.orderedIndex < $1.key.orderedIndex })

        if touch.state == .down {
            if let (window, manager) = windows.first(where: { $0.key.frame.contains(touch.position) && windowSubviews($0.key, contains: touch, in: $0.value.responder) }) {
                return (window, manager)
            }
        } else {
            if let (window, manager) = windows.first(where: { $0.value.owns(touch) && windowSubviews($0.key, contains: touch, in: $0.value.responder) }) {
                return (window, manager)
            }
        }

        return nil
    }

    private func windowSubviews(_ window: NSWindow, contains touch: Touch, in responder: GestureResponder) -> Bool {
        return responder.subview(contains: touch.position.transformed(to: window.frame))
    }

    /// Updates the touches for map dictionary when a touch down or up occurs.
    private func updateTouchesForApp(with touch: Touch, for app: Int) {
        switch touch.state {
        case .down:
            if touchesForAppID[app] != nil {
                touchesForAppID[app]!.insert(touch)
            } else {
                touchesForAppID[app] = Set([touch])
            }
        case .up:
            if touchesForAppID[app] != nil {
                touchesForAppID[app]!.remove(touch)
            }
        case .moved:
            return
        }
    }

    /// Converts a position received from a touch screen to the coordinate of the current devices bounds.
    private func convert(_ touch: Touch, toScreen screen: Int) {
        let screen = NSScreen.at(position: screen)
        let xPos = (touch.position.x / Configuration.touchScreen.touchSize.width * CGFloat(screen.frame.width)) + screen.frame.origin.x
        let yPos = (1 - touch.position.y / Configuration.touchScreen.touchSize.height) * CGFloat(screen.frame.height)
        touch.position = CGPoint(x: xPos, y: yPos)
    }

    private func appOwner(of touch: Touch) -> (Int, ApplicationType)? {
        guard let (appID, _) = touchesForAppID.first(where: { $0.value.contains(touch) }) else {
            return nil
        }

        let type = ConnectionManager.instance.typeForApp(id: appID)
        return (appID, type)
    }

    /// Calculates the map index based off the x-position of the touch and the screens
    private func calculateApp(for touch: Touch) -> (Int, ApplicationType) {
        let screen = NSScreen.at(position: touch.screen)
        let baseAppForScreen = (touch.screen - 1) * Int(Configuration.appsPerScreen)
        let appWidth = screen.frame.width / CGFloat(Configuration.appsPerScreen) + 1
        let appForScreen = Int((touch.position.x - screen.frame.minX) / appWidth)
        let app = baseAppForScreen + appForScreen
        let type = ConnectionManager.instance.typeForApp(id: app)
        return (app, type)
    }

    private func app(_ app: Int, contains touch: Touch) -> Bool {
        let screen = NSScreen.at(position: touch.screen)
        let appWidth = screen.frame.width / CGFloat(Configuration.appsPerScreen)
        let appInScreen = CGFloat(app % Configuration.appsPerScreen)
        let minX = screen.frame.minX + (appInScreen * appWidth)
        let maxX = minX + appWidth
        return touch.position.x >= minX && touch.position.x <= maxX
    }

    /// Determines if a touch being sent to a map needs to be sent. To reduce the number of notifications sent, we only send every second moved event.
    private func shouldSend(_ touch: Touch) -> Bool {
        switch touch.state {
        case .down:
            touchNeedsUpdate[touch] = false
        case .up:
            touchNeedsUpdate.removeValue(forKey: touch)
        case .moved:
            if let update = touchNeedsUpdate[touch] {
                touchNeedsUpdate[touch] = !update
                return update
            }
        }

        return true
    }
}
