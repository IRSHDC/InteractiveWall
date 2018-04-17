//  Copyright © 2018 JABT. All rights reserved.

import Cocoa
import AppKit
import Alamofire
import AlamofireImage

class ImageViewController: MediaViewController {
    static let storyboard = NSStoryboard.Name(rawValue: "Image")

    @IBOutlet weak var imageScrollView: RegularScrollView!
    @IBOutlet weak var windowDragArea: NSView!
    @IBOutlet weak var windowDragAreaHighlight: NSView!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var scrollViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var dismissButton: NSView!

    private var urlRequest: DataRequest?
    private var imageView: NSImageView!
    private var contentViewFrame: NSRect!
    private var frameSize: NSSize!

    private struct Constants {
        static let initialMagnification: CGFloat = 1
        static let maximumMagnification: CGFloat = 5
    }


    // MARK: Life-cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.attributedStringValue = NSAttributedString(string: media.title ?? "", attributes: titleAttributes)

        setupImageView()
        setupGestures()
        setupWindowDragArea()
        animateViewIn()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        urlRequest?.cancel()
    }


    // MARK: Setup

    private func setupImageView() {
        guard media.type == .image else {
            return
        }

        imageScrollView.minMagnification = Constants.initialMagnification
        imageScrollView.maxMagnification = Constants.maximumMagnification
        imageView = NSImageView()

        urlRequest = Alamofire.request(media.url).responseImage { [weak self] response in
            if let image = response.value {
                self?.addImage(image)
            }
        }
    }

    private func addImage(_ image: NSImage) {
        imageView.image = image
        imageView.imageScaling = NSImageScaling.scaleAxesIndependently
        
        let imageRatio = image.size.height / image.size.width
        let width = clamp(image.size.width, min: style.minMediaWindowWidth, max: style.maxMediaWindowWidth)
        let height = width * imageRatio
        frameSize = NSSize(width: width, height: height)
        imageView.setFrameSize(frameSize)
        scrollViewHeightConstraint.constant = frameSize.height
        scrollViewWidthConstraint.constant = frameSize.width
        imageScrollView.documentView = imageView
    }

    private func setupGestures() {
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handleMousePan(_:)))
        view.addGestureRecognizer(panGesture)

        let windowPan = PanGestureRecognizer()
        gestureManager.add(windowPan, to: windowDragArea)
        windowPan.gestureUpdated = handleWindowPan(_:)

        let pinchGesture = PinchGestureRecognizer()
        gestureManager.add(pinchGesture, to: imageScrollView)
        pinchGesture.gestureUpdated = didPinchImageView(_:)

        let singleFingerCloseButtonTap = TapGestureRecognizer()
        gestureManager.add(singleFingerCloseButtonTap, to: dismissButton)
        singleFingerCloseButtonTap.gestureUpdated = didTapCloseButton(_:)
    }

    private func setupWindowDragArea() {
        windowDragArea.wantsLayer = true
        windowDragArea.layer?.backgroundColor = style.dragAreaBackground.cgColor
        windowDragAreaHighlight.wantsLayer = true
        windowDragAreaHighlight.layer?.backgroundColor = media.tintColor.cgColor
    }

    
    // MARK: Gesture Handling

    private func handleWindowPan(_ gesture: GestureRecognizer) {
        guard let pan = gesture as? PanGestureRecognizer, let window = view.window, !animating else {
            return
        }

        switch pan.state {
        case .began:
            delegate?.controllerDidMove(self)
        case .recognized, .momentum:
            var origin = window.frame.origin
            origin += pan.delta.round()
            window.setFrameOrigin(origin)
        case .possible:
            WindowManager.instance.checkBounds(of: self)
        default:
            return
        }
    }

    private func didPinchImageView(_ gesture: GestureRecognizer) {
        guard let pinch = gesture as? PinchGestureRecognizer, !animating else {
            return
        }

        switch pinch.state {
        case .began:
            contentViewFrame = imageScrollView.contentView.frame
        case .recognized, .momentum:
            let newMagnification = clamp(imageScrollView.magnification + (pinch.scale - 1), min: Constants.initialMagnification, max: Constants.maximumMagnification)
            imageScrollView.setMagnification(newMagnification, centeredAt: pinch.center)
            let currentRect = imageScrollView.contentView.bounds
            let newOriginX = min(contentViewFrame.origin.x + contentViewFrame.width - currentRect.width, max(contentViewFrame.origin.x, currentRect.origin.x - pinch.delta.dx / newMagnification))
            let newOriginY = min(contentViewFrame.origin.y + contentViewFrame.height - currentRect.height, max(contentViewFrame.origin.y, currentRect.origin.y - pinch.delta.dy / newMagnification))
            imageScrollView.contentView.scroll(to: NSPoint(x: newOriginX, y: newOriginY))
        default:
            return
        }
    }

    private func didTapCloseButton(_ gesture: GestureRecognizer) {
        guard let tap = gesture as? TapGestureRecognizer, tap.state == .ended, !animating else {
            return
        }

        animateViewOut()
    }

    @objc
    private func handleMousePan(_ gesture: NSPanGestureRecognizer) {
        guard let window = view.window, !animating else {
            return
        }

        resetCloseWindowTimer()
        var origin = window.frame.origin
        origin += gesture.translation(in: nil)
        window.setFrameOrigin(origin)
    }


    // MARK: IB-Actions

    @IBAction func closeButtonTapped(_ sender: Any) {
        animateViewOut()
    }

    
    // MARK: GestureResponder

    /// Determines if the bounds of the draggable area is inside a given rect
    override func draggableInside(bounds: CGRect) -> Bool {
        guard let window = view.window else {
            return false
        }

        // Calculate the center box of the drag area in the window's coordinate system
        let dragAreaInWindow = windowDragArea.frame.transformed(from: view.frame).transformed(from: window.frame)
        let adjustedWidth = dragAreaInWindow.width / 2
        let smallDragArea = CGRect(x: dragAreaInWindow.minX + adjustedWidth / 2, y: dragAreaInWindow.minY, width: adjustedWidth, height: dragAreaInWindow.height)
        return bounds.contains(smallDragArea)
    }
}
