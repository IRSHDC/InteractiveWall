//  Copyright © 2018 JABT. All rights reserved.

import Cocoa
import Alamofire
import AlamofireImage


class RecordCollectionItemView: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "RecordCollectionItemView")

    @IBOutlet weak var mediaImageView: ImageView!
    @IBOutlet weak var titleTextField: NSTextField!

    var tintColor = style.collectionColor
    var record: Record? {
        didSet {
            load(record)
        }
    }

    private struct Constants {
        static let imageTransitionDuration = 0.3
        static let screenEdgeMargin: CGFloat = 15
        static let interItemMargin: CGFloat = 5
    }


    // MARK: Init

    override func awakeFromNib() {
        super.awakeFromNib()
        view.wantsLayer = true
        set(highlighted: false)
    }


    // MARK: API

    func set(highlighted: Bool) {
        if highlighted {
            view.layer?.backgroundColor = tintColor.cgColor
        } else {
            view.layer?.backgroundColor = CGColor.clear
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        mediaImageView.set(nil)
    }


    // MARK: Helpers

    private func load(_ record: Record?) {
        guard let record = record else {
            return
        }

        titleTextField.attributedStringValue = NSAttributedString(string: record.shortestTitle(), attributes: style.recordSmallHeaderAttributes)

        let placeholder = record.type.placeholder.tinted(with: record.type.color)
        if let media = record.media.first, let thumbnail = media.thumbnail {
            Alamofire.request(thumbnail).responseImage { [weak self] response in
                if let image = response.value {
                    self?.setImage(image, scaling: .aspectFill)
                } else {
                    self?.setImage(placeholder, scaling: .center)
                }
            }
        } else {
            setImage(placeholder, scaling: .center)
        }
    }

    private func setImage(_ image: NSImage?, scaling: ImageScaling) {
        mediaImageView.layer?.backgroundColor = style.relatedItemBackgroundColor.cgColor
        mediaImageView.transition(image, duration: Constants.imageTransitionDuration, scaling: scaling)
    }
}