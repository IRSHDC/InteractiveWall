//  Copyright © 2018 JABT. All rights reserved.

import Foundation
import AppKit


final class WindowFactory {


    // MARK: API

    static func window(for type: WindowType, at origin: CGPoint) -> NSWindow {
        let viewController = controller(for: type)
        viewController.view.setFrameSize(type.size)
        let window = BorderlessWindow(frame: CGRect(origin: origin, size: type.size), controller: viewController)
        window.makeKeyAndOrderFront(self)
        return window
    }


    // MARK: Helpers

    private static func controller(for type: WindowType) -> NSViewController {
        switch type {
        case let .record(displayable):
            let storyboard = NSStoryboard(name: RecordViewController.storyboard, bundle: .main)
            let recordViewController = storyboard.instantiateInitialController() as! RecordViewController
            recordViewController.record = displayable
            recordViewController.type = type
            return recordViewController
        case let .image(media):
            let storyboard = NSStoryboard(name: ImageViewController.storyboard, bundle: .main)
            let imageViewController = storyboard.instantiateInitialController() as! ImageViewController
            imageViewController.media = media
            imageViewController.type = type
            return imageViewController
        case let .player(media):
            let storyboard = NSStoryboard(name: PlayerViewController.storyboard, bundle: .main)
            let playerViewController = storyboard.instantiateInitialController() as! PlayerViewController
            playerViewController.media = media
            playerViewController.type = type
            return playerViewController
        case let .pdf(media):
            let storyboard = NSStoryboard(name: PDFViewController.storyboard, bundle: .main)
            let pdfViewController = storyboard.instantiateInitialController() as! PDFViewController
            pdfViewController.media = media
            pdfViewController.type = type
            return pdfViewController
        case .search:
            let storyboard = NSStoryboard(name: SearchViewController.storyboard, bundle: .main)
            let searchViewController = storyboard.instantiateInitialController() as! SearchViewController
            searchViewController.type = type
            return searchViewController
        case .menu:
            let storyboard = NSStoryboard(name: MenuViewController.storyboard, bundle: .main)
            return storyboard.instantiateInitialController() as! MenuViewController
        case .settings:
            let storyboard = NSStoryboard(name: SettingsMenuViewController.storyboard, bundle: .main)
            return storyboard.instantiateInitialController() as! SettingsMenuViewController
        case .border:
            let storyboard = NSStoryboard(name: BorderViewController.storyboard, bundle: .main)
            return storyboard.instantiateInitialController() as! BorderViewController
        case .testimony:
            let storyboard = NSStoryboard(name: TestimonyViewController.storyboard, bundle: .main)
            return storyboard.instantiateInitialController() as! TestimonyViewController
        }
    }
}
