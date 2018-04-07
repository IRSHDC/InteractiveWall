//  Copyright © 2018 JABT. All rights reserved.

import Cocoa
import AppKit

class RecordViewController: NSViewController, NSCollectionViewDelegateFlowLayout, NSCollectionViewDataSource, NSTableViewDataSource, NSTableViewDelegate, GestureResponder, MediaControllerDelegate {
    static let storyboard = NSStoryboard.Name(rawValue: "Record")

    @IBOutlet weak var detailView: NSView!
    @IBOutlet weak var windowDragArea: NSView!
    @IBOutlet weak var windowDragAreaHighlight: NSView!
    @IBOutlet weak var mediaView: NSCollectionView!
    @IBOutlet weak var collectionClipView: NSClipView!
    @IBOutlet weak var stackView: NSStackView!
    @IBOutlet weak var stackClipView: NSClipView!
    @IBOutlet weak var relatedItemsView: NSTableView!
    @IBOutlet weak var closeWindowTapArea: NSView!
    @IBOutlet weak var toggleRelatedItemsArea: NSView!
    @IBOutlet weak var showRelatedItemsView: NSImageView!
    @IBOutlet weak var hideRelatedItemsButton: NSButton!
    @IBOutlet weak var placeHolderImage: NSImageView!

    var record: RecordDisplayable!
    private(set) var gestureManager: GestureManager!
    private var showingRelatedItems = false
    private var pageControl = PageControl()
    private var positionsForMediaControllers = [MediaViewController: Int?]()
    private weak var closeWindowTimer: Foundation.Timer?
    private var animating: Bool = false
    
    private struct Constants {
        static let tableRowHeight: CGFloat = 80
        static let windowMargins: CGFloat = 20
        static let mediaControllerOffset = 50
        static let closeWindowTimeoutPeriod: TimeInterval = 60
        static let animationDistanceThreshold: CGFloat = 20
        static let fontName = "Soleil"
        static let fontSize: CGFloat = 13
        static let fontColor: NSColor = .white
        static let kern: CGFloat = 0.5
        static let screenEdgeBuffer: CGFloat = 80
    }


    // MARK: Life-cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        detailView.alphaValue = 0.0
        detailView.wantsLayer = true
        detailView.layer?.backgroundColor = style.darkBackground.cgColor
        windowDragArea.wantsLayer = true
        windowDragArea.layer?.backgroundColor = style.dragAreaBackground.cgColor
        placeHolderImage.isHidden = !record.media.isEmpty
        gestureManager = GestureManager(responder: self)
        gestureManager.touchReceived = recievedTouch(touch:)

        setupMediaView()
        setupRelatedItemsView()
        setupGestures()
        loadRecord()
        animateViewIn()
        resetCloseWindowTimer()
        setupWindowDragArea()
    }


    // MARK: Setup

    private func setupMediaView() {
        mediaView.register(MediaItemView.self, forItemWithIdentifier: MediaItemView.identifier)
        placeHolderImage.image = record.type.placeholder.tinted(with: record.type.color)
        pageControl.color = .white
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.wantsLayer = true
        detailView.addSubview(pageControl)

        pageControl.centerXAnchor.constraint(equalTo: detailView.centerXAnchor).isActive = true
        pageControl.widthAnchor.constraint(equalTo: detailView.widthAnchor).isActive = true
        pageControl.topAnchor.constraint(equalTo: mediaView.bottomAnchor).isActive = true
        pageControl.heightAnchor.constraint(equalToConstant: 20).isActive = true
        pageControl.numberOfPages = UInt(record?.media.count ?? 0)
    }
    
    private var titleBarAttributes : [NSAttributedStringKey : Any] {
        let font = NSFont(name: Constants.fontName, size: Constants.fontSize) ?? NSFont.systemFont(ofSize: Constants.fontSize)
        
        return [.font : font,
                .foregroundColor : Constants.fontColor,
                .kern : Constants.kern,
                .baselineOffset : font.fontName == Constants.fontName ? 1.0 : 0.0]
    }

    private func setupRelatedItemsView() {
        relatedItemsView.alphaValue = 0
        relatedItemsView.register(NSNib(nibNamed: RelatedItemView.nibName, bundle: nil), forIdentifier: RelatedItemView.interfaceIdentifier)
        relatedItemsView.backgroundColor = .clear
        showRelatedItemsView.isHidden = record.relatedRecords.isEmpty
        hideRelatedItemsButton.font = NSFont(name: Constants.fontName, size: Constants.fontSize) ?? NSFont.systemFont(ofSize: Constants.fontSize)
        hideRelatedItemsButton.attributedTitle = NSAttributedString(string: hideRelatedItemsButton.title, attributes: titleBarAttributes)

    }

    private func setupGestures() {
        let nsPanGesture = NSPanGestureRecognizer(target: self, action: #selector(handleMouseDrag(_:)))
        detailView.addGestureRecognizer(nsPanGesture)

        let collectionViewPanGesture = PanGestureRecognizer()
        gestureManager.add(collectionViewPanGesture, to: mediaView)
        collectionViewPanGesture.gestureUpdated = handleCollectionViewPan(_:)

        let collectionViewTapGesture = TapGestureRecognizer()
        gestureManager.add(collectionViewTapGesture, to: mediaView)
        collectionViewTapGesture.gestureUpdated = handleCollectionViewTap(_:)

        let relatedViewPan = PanGestureRecognizer()
        gestureManager.add(relatedViewPan, to: relatedItemsView)
        relatedViewPan.gestureUpdated = handleRelatedViewPan(_:)

        let relatedItemTap = TapGestureRecognizer()
        gestureManager.add(relatedItemTap, to: relatedItemsView)
        relatedItemTap.gestureUpdated = handleRelatedItemTap(_:)

        let panGesture = PanGestureRecognizer()
        gestureManager.add(panGesture, to: windowDragArea)
        panGesture.gestureUpdated = handleWindowPan(_:)

        let stackViewPanGesture = PanGestureRecognizer()
        gestureManager.add(stackViewPanGesture, to: stackView)
        stackViewPanGesture.gestureUpdated = handleStackViewPan(_:)

        let toggleRelatedItemsTap = TapGestureRecognizer()
        gestureManager.add(toggleRelatedItemsTap, to: toggleRelatedItemsArea)
        toggleRelatedItemsTap.gestureUpdated = handleRelatedItemsToggle(_:)

        let tapToClose = TapGestureRecognizer()
        gestureManager.add(tapToClose, to: closeWindowTapArea)
        tapToClose.gestureUpdated = { [weak self] gesture in
            if gesture.state == .ended {
                self?.animateViewOut()
            }
        }
    }

    private func loadRecord() {
        for label in record.textFields {
            stackView.insertView(label, at: stackView.subviews.count, in: .top)
        }
    }

    private func setupWindowDragArea() {
        windowDragAreaHighlight.wantsLayer = true
        windowDragAreaHighlight.layer?.backgroundColor = record.type.color.cgColor
    }

    // MARK: Gesture Handling

    private func handleCollectionViewPan(_ gesture: GestureRecognizer) {
        guard let pan = gesture as? PanGestureRecognizer, !animating else {
            return
        }

        switch pan.state {
        case .recognized, .momentum:
            var rect = mediaView.visibleRect
            rect.origin.x -= pan.delta.dx
            mediaView.scrollToVisible(rect)
        case .possible:
            let rect = mediaView.visibleRect
            let offset = rect.origin.x / rect.width
            let index = round(offset)
            let margin = offset.truncatingRemainder(dividingBy: 1)
            let duration = margin < 0.5 ? margin : 1 - margin
            let origin = CGPoint(x: rect.width * index, y: 0)
            animateCollectionView(to: origin, duration: duration, for: Int(index))
        default:
            return
        }
    }

    private var selectedMediaItem: MediaItemView? {
        didSet {
            oldValue?.set(highlighted: false)
            selectedMediaItem?.set(highlighted: true)
        }
    }

    private func handleCollectionViewTap(_ gesture: GestureRecognizer) {
        guard let tap = gesture as? TapGestureRecognizer, !animating else {
            return
        }

        let rect = mediaView.visibleRect
        let offset = rect.origin.x / rect.width
        let index = Int(round(offset))
        let indexPath = IndexPath(item: index, section: 0)
        guard let mediaItem = mediaView.item(at: indexPath) as? MediaItemView else {
            return
        }

        switch tap.state {
        case .began:
            selectedMediaItem = mediaItem
        case .failed:
            selectedMediaItem = nil
        case .ended:
            if let selectedMedia = selectedMediaItem?.media {
                selectMediaItem(selectedMedia)
                selectedMediaItem = nil
            }
        default:
            return
        }
    }

    private func handleRelatedViewPan(_ gesture: GestureRecognizer) {
        guard let pan = gesture as? PanGestureRecognizer, !animating else {
            return
        }

        switch pan.state {
        case .recognized, .momentum:
            var rect = relatedItemsView.visibleRect
            rect.origin.y += pan.delta.dy
            relatedItemsView.scrollToVisible(rect)
        default:
            return
        }
    }

    private func handleRelatedItemsToggle(_ gesture: GestureRecognizer) {
        guard let tap = gesture as? TapGestureRecognizer, tap.state == .ended, !record.relatedRecords.isEmpty else {
            return
        }

        toggleRelatedItems()
    }

    private var selectedRelatedItem: RelatedItemView? {
        didSet {
            oldValue?.set(highlighted: false)
            selectedRelatedItem?.set(highlighted: true)
        }
    }

    private func handleRelatedItemTap(_ gesture: GestureRecognizer) {
        guard let tap = gesture as? TapGestureRecognizer, let location = tap.position, !animating else {
            return
        }

        let locationInTable = location + relatedItemsView.visibleRect.origin
        let row = relatedItemsView.row(at: locationInTable)
        guard row >= 0, let relatedItemView = relatedItemsView.view(atColumn: 0, row: row, makeIfNecessary: false) as? RelatedItemView else {
            return
        }

        switch tap.state {
        case .began:
            selectedRelatedItem = relatedItemView
        case .failed:
            selectedRelatedItem = nil
        case .ended:
            if let selectedRecord = selectedRelatedItem?.record {
                selectRelatedItem(selectedRecord)
                selectedRelatedItem = nil
            }
        default:
            return
        }
    }

    private func handleStackViewPan(_ gesture: GestureRecognizer) {
        guard let pan = gesture as? PanGestureRecognizer, !animating else {
            return
        }

        switch pan.state {
        case .recognized, .momentum:
            var point = stackClipView.visibleRect.origin
            point.y += pan.delta.dy
            stackClipView.scroll(point)
        default:
            return
        }
    }

    private func handleWindowPan(_ gesture: GestureRecognizer) {
        guard let pan = gesture as? PanGestureRecognizer, let window = view.window, !animating else {
            return
        }

        recordMoved()

        switch pan.state {
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

    @objc
    private func handleMouseDrag(_ gesture: NSPanGestureRecognizer) {
        guard let window = view.window, !animating else {
            return
        }

        var origin = window.frame.origin
        origin += gesture.translation(in: nil)
        window.setFrameOrigin(origin)
        WindowManager.instance.checkBounds(of: self)
    }


    // MARK: IB-Actions

    @IBAction func toggleRelatedItems(_ sender: Any) {
        toggleRelatedItems()
    }

    @IBAction func closeWindowTapped(_ sender: Any) {
        animateViewOut()
    }


    // MARK: Helpers

    private func animateViewIn() {
        NSAnimationContext.runAnimationGroup({ _ in
            NSAnimationContext.current.duration = 0.5
            detailView.animator().alphaValue = 1.0
        })
    }

    private func animateViewOut() {
        NSAnimationContext.runAnimationGroup({ _ in
            NSAnimationContext.current.duration = 0.5
            detailView.animator().alphaValue = 0.0
            relatedItemsView.animator().alphaValue = 0.0
        }, completionHandler: {
            WindowManager.instance.closeWindow(for: self)
        })
    }

    private func animateCollectionView(to point: CGPoint, duration: CGFloat, for index: Int) {
        NSAnimationContext.runAnimationGroup({ _ in
            NSAnimationContext.current.duration = TimeInterval(duration)
            collectionClipView.animator().setBoundsOrigin(point)
            }, completionHandler: { [weak self] in
                self?.pageControl.selectedPage = UInt(index)
        })
    }

    func animate(to origin: NSPoint) {
        guard let window = self.view.window, shouldAnimate(to: origin), !gestureManager.isActive() else {
            return
        }

        resetCloseWindowTimer()
        var frame = window.frame
        frame.origin = origin
        window.makeKeyAndOrderFront(self)
        animating = true

        NSAnimationContext.runAnimationGroup({ _ in
            NSAnimationContext.current.duration = 0.75
            NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
            window.animator().setFrame(frame, display: true, animate: true)
        }, completionHandler: { [weak self] in
            self?.animating = false
        })
    }

    private func toggleRelatedItems(completion: (() -> Void)? = nil) {
        guard let window = view.window else {
            return
        }

        relatedItemsView.isHidden = false
        hideRelatedItemsButton.isHidden = false
        let alpha: CGFloat = showingRelatedItems ? 0 : 1

        NSAnimationContext.runAnimationGroup({ [weak self] _ in
            NSAnimationContext.current.duration = 0.5
            self?.relatedItemsView.animator().alphaValue = alpha
            self?.hideRelatedItemsButton.animator().alphaValue = alpha
            self?.showRelatedItemsView.image = showingRelatedItems ? NSImage(named: "plus-icon") : NSImage(named: "close button")
            }, completionHandler: { [weak self] in
                if let strongSelf = self {
                    strongSelf.relatedItemsView.isHidden = !strongSelf.showingRelatedItems
                    strongSelf.hideRelatedItemsButton.isHidden = !strongSelf.showingRelatedItems
                }
                completion?()
        })

        let diff: CGFloat = showingRelatedItems ? -256 : 256
        var frame = window.frame
        frame.size.width += diff
        window.setFrame(frame, display: true, animate: true)
        showingRelatedItems = !showingRelatedItems
    }

    private func selectRelatedItem(_ record: RecordDisplayable) {
        guard let window = view.window else {
            return
        }

        toggleRelatedItems(completion: {
            let origin = CGPoint(x: window.frame.maxX + Constants.windowMargins, y: window.frame.minY)
            RecordFactory.record(for: record.type, id: record.id, completion: { newRecord in
                if let loadedRecord = newRecord {
                    WindowManager.instance.display(.record(loadedRecord), at: origin)
                }
            })
        })
    }

    private func selectMediaItem(_ media: Media) {
        guard let window = view.window, let windowType = WindowType(for: media), let lastScreen = NSScreen.screens.last else {
            return
        }

        var controller: MediaViewController?

        if let mediaController = positionsForMediaControllers.keys.first(where: {$0.media == media}) {
            if positionsForMediaControllers[mediaController]! == nil as Int? {
                controller = mediaController
            } else {
                mediaController.view.window?.makeKeyAndOrderFront(self)
                return
            }
        }

        let position = getMediaControllerPosition()
        let offsetX = position * Constants.mediaControllerOffset
        let offsetY = position * -Constants.mediaControllerOffset
        let windowHeight = controller == nil ? windowType.size.height : controller!.view.frame.height
        let originX = window.frame.maxX + Constants.windowMargins + CGFloat(offsetX)
        let originY = window.frame.maxY - windowHeight + CGFloat(offsetY)
        let origin = getAdjustedOrigin(CGPoint(x: originX, y: originY), on: window, and: lastScreen, with: windowType)

        if let mediaController = controller {
            mediaController.animate(to: origin)
            positionsForMediaControllers[mediaController] = position
            mediaController.moved = false
        } else if let mediaController = WindowManager.instance.display(windowType, at: origin) as? MediaViewController {
            positionsForMediaControllers[mediaController] = position
            mediaController.delegate = self
        }
    }

    /// Returns the origin, adjusting if it will be displaying a record off the map
    private func getAdjustedOrigin(_ origin: CGPoint, on window: NSWindow, and lastScreen: NSScreen, with windowType: WindowType) -> NSPoint {
        let totalWidth = NSScreen.screens.reduce(0) { $0 + $1.frame.width }
        if origin.x > totalWidth - Constants.screenEdgeBuffer, windowType.canAdjustOrigin {
            if lastScreen.frame.height - window.frame.maxY < windowType.size.height {
                return NSPoint(x: totalWidth - windowType.size.width - Constants.windowMargins, y: origin.y - view.frame.height - Constants.windowMargins)
            } else {
                return NSPoint(x: totalWidth - windowType.size.width - Constants.windowMargins, y: origin.y + windowType.size.height + Constants.windowMargins)
            }
        }

        return origin
    }

    /// Gets the position that is missing from 0 to the largestPosition
    private func getMediaControllerPosition() -> Int {
        let sortedPosition = positionsForMediaControllers.values.compactMap{$0}.sorted(by: { $0 < $1 })

        guard let lastPosition = sortedPosition.last else {
            return 0
        }

        for index in 0...lastPosition {
            if index != sortedPosition[index] {
                return index
            }
        }

        return lastPosition + 1
    }

    private func resetCloseWindowTimer() {
        closeWindowTimer?.invalidate()
        closeWindowTimer = Timer.scheduledTimer(withTimeInterval: Constants.closeWindowTimeoutPeriod, repeats: false) { [weak self] _ in
            self?.closeTimerFired()
        }
    }

    private func closeTimerFired() {
        // reset timer gets recalled once a child MediaViewContoller gets closed
        if positionsForMediaControllers.keys.isEmpty {
            animateViewOut()
        }
    }

    private func recievedTouch(touch: Touch) {
        resetCloseWindowTimer()
    }

    /// If the position of the controller is close enough to the origin of animation, don't animate
    private func shouldAnimate(to origin: NSPoint) -> Bool {
        guard let currentOrigin = self.view.window?.frame.origin else {
            return false
        }

        let originDifference = currentOrigin - origin
        return abs(originDifference.x) > Constants.animationDistanceThreshold || abs(originDifference.y) > Constants.animationDistanceThreshold ? true : false
    }

    private func recordMoved() {
        positionsForMediaControllers.keys.forEach { positionsForMediaControllers[$0] = nil as Int? }
    }


    // MARK: NSCollectionViewDelegate & NSCollectionViewDataSource

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return record?.media.count ?? 0
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        guard let mediaItemView = collectionView.makeItem(withIdentifier: MediaItemView.identifier, for: indexPath) as? MediaItemView else {
            return NSCollectionViewItem()
        }

        mediaItemView.media = record.media[indexPath.item]
        mediaItemView.tintColor = record.type.color
        return mediaItemView
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        return collectionClipView.frame.size
    }


    // MARK: NSTableViewDataSource & NSTableViewDelegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        return record?.relatedRecords.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let relatedItemView = tableView.makeView(withIdentifier: RelatedItemView.interfaceIdentifier, owner: self) as? RelatedItemView else {
            return nil
        }

        relatedItemView.record = record.relatedRecords[row]
        relatedItemView.tintColor = record.type.color
        return relatedItemView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return Constants.tableRowHeight
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }


    // MARK: MediaControllerDelegate

    func closeWindow(for mediaController: MediaViewController) {
        positionsForMediaControllers.removeValue(forKey: mediaController)
        resetCloseWindowTimer()
    }

    func moved(for mediaController: MediaViewController) {
        positionsForMediaControllers[mediaController] = nil as Int?
    }
}
