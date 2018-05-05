//  Copyright © 2018 JABT. All rights reserved.

import Cocoa

class SearchViewController: BaseViewController, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {
    static let storyboard = NSStoryboard.Name(rawValue: "Search")

    @IBOutlet weak var primaryCollectionView: NSCollectionView!

    private struct Constants {
        static let animationDuration = 0.5
    }


    // MARK: Life-Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupGestures()
        setupCollectionViews()
        setupWindowDragArea()
        resetCloseWindowTimer()
        animateViewIn()
    }


    // MARK: Setup

    private func setupCollectionViews() {
        
    }

    private func setupWindowDragArea() {
        titleLabel.attributedStringValue = NSAttributedString(string: titleLabel.stringValue, attributes: style.windowTitleAttributes)
    }

    private func setupGestures() {

    }


    // MARK: GestureHandling



    // MARK: NSCollectionViewDelegate & NSCollectionViewDataSource

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return 20
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        guard let searchItemView = collectionView.makeItem(withIdentifier: SearchItemView.identifier, for: indexPath) as? SearchItemView else {
            return NSCollectionViewItem()
        }

        return searchItemView
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        return CGSize(width: collectionView.frame.size.width, height: 70)
    }



    // MARK: Helpers

    override func animateViewIn() {
        primaryCollectionView.alphaValue = 0
        windowDragArea.alphaValue = 0
        NSAnimationContext.runAnimationGroup({ _ in
            NSAnimationContext.current.duration = Constants.animationDuration
            primaryCollectionView.animator().alphaValue = 1
            windowDragArea.animator().alphaValue = 1
        })
    }

    override func animateViewOut() {
        NSAnimationContext.runAnimationGroup({ _ in
            NSAnimationContext.current.duration = Constants.animationDuration
            view.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            if let strongSelf = self {
                WindowManager.instance.closeWindow(for: strongSelf)
            }
        })
    }
}