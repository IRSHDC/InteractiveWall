//  Copyright © 2018 JABT. All rights reserved.

import Cocoa


class RelatedItemListView: RelatedItemView {
    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "RelatedItemListView")

    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionView: NSTextView!


    // MARK: Life-Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        descriptionView.drawsBackground = false
        descriptionView.textContainer?.maximumNumberOfLines = Constants.numberOfDescriptionLines
    }


    // MARK: Overrides

    override func load(_ record: Record) {
        super.load(record)

        titleLabel.attributedStringValue = NSAttributedString(string: record.title, attributes: style.relatedItemViewTitleAttributes)
        let description = NSAttributedString(string: record.description ?? "", attributes: style.relatedItemViewDescriptionAttributes)
        descriptionView.textStorage?.setAttributedString(description)
    }
}
