//  Copyright © 2018 JABT. All rights reserved.

import Cocoa

class SearchItemView: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("SearchItemView")

    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var spinner: NSProgressIndicator!

    var tintColor = style.selectedColor

    var type: RecordType? {
        didSet {
            tintColor = type?.color ?? style.selectedColor
        }
    }

    var item: SearchItemDisplayable! {
        didSet {
            apply(item)
        }
    }

    private struct Constants {
        static let animationDuration = 0.2
    }


    // MARK: Life-Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        set(highlighted: false)
    }


    // MARK: API

    func set(highlighted: Bool) {
        if highlighted {
            view.layer?.backgroundColor = tintColor.cgColor
        } else {
            view.layer?.backgroundColor = style.darkBackground.cgColor
        }
    }

    func set(loading: Bool) {
        if loading {
            spinner.startAnimation(self)
        } else {
            spinner.stopAnimation(self)
        }

        titleTextField.isHidden = loading
        spinner.isHidden = !loading
    }


    // MARK: Helpers

    private func apply(_ item: SearchItemDisplayable?) {
        titleTextField.stringValue = item?.title ?? ""

        if let recordType = item as? RecordType {
            type = recordType
        }
    }
}
