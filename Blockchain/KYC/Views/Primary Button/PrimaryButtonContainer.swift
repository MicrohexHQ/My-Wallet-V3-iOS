//
//  PrimaryButton.swift
//  Blockchain
//
//  Created by Maurice A. on 7/9/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import UIKit

@IBDesignable
class PrimaryButtonContainer: NibBasedView {
    
    enum PrimaryButtonFont: Int {
        case kyc = 0
        case send = 1
        case small = 2
        
        var font: UIFont {
            switch self {
            case .kyc:
                return UIFont(
                    name: Constants.FontNames.montserratMedium,
                    size: 20.0
                    ) ?? UIFont.systemFont(ofSize: 20, weight: .medium)
            case .send:
                return UIFont(
                    name: Constants.FontNames.montserratRegular,
                    size: 17.0
                    ) ?? UIFont.systemFont(ofSize: 17.0, weight: .regular)
            case .small:
                return UIFont(
                    name: Constants.FontNames.montserratRegular,
                    size: 14.0
                ) ?? UIFont.systemFont(ofSize: 14.0, weight: .regular)
            }
        }
    }

    // MARK: Private IBOutlets

    @IBOutlet fileprivate var activityIndicator: UIActivityIndicatorView!
    @IBOutlet fileprivate var primaryButton: UIButton!

    // MARK: Public

    /// Simple block for handling the call back when the
    /// `primaryButton` is tapped.
    var actionBlock: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        primaryButton.layer.cornerRadius = 4.0
    }

    var activityIndicatorStyle: UIActivityIndicatorView.Style = .whiteLarge {
        didSet {
            activityIndicator.style = activityIndicatorStyle
        }
    }

    // MARK: IBInspectable
    
    @IBInspectable var primaryButtonFont: Int = 0 {
        didSet {
            let value = PrimaryButtonFont(rawValue: primaryButtonFont) ?? .kyc
            primaryButton.titleLabel?.font = value.font
        }
    }

    @IBInspectable var buttonBackgroundColor: UIColor = UIColor.brandSecondary {
        didSet {
            primaryButton.backgroundColor = buttonBackgroundColor
        }
    }

    @IBInspectable var buttonTitleColor: UIColor = UIColor.white {
        didSet {
            primaryButton.setTitleColor(buttonTitleColor, for: .normal)
        }
    }
    
    @IBInspectable var disabledButtonBackgroundColor: UIColor = UIColor.brandSecondary

    @IBInspectable var isLoading: Bool = false {
        didSet {
            isLoading == true ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
            isLoading == true ? primaryButton.setTitle(nil, for: .normal) : primaryButton.setTitle(title, for: .normal)
        }
    }

    @IBInspectable var title: String = "" {
        didSet {
            primaryButton.setTitle(title, for: .normal)
        }
    }

    @IBInspectable var attributedTitle: NSAttributedString = NSAttributedString(string: "") {
        didSet {
            primaryButton.setAttributedTitle(attributedTitle, for: .normal)
        }
    }

    @IBInspectable var isEnabled: Bool = true {
        didSet {
            primaryButton.isEnabled = isEnabled
            primaryButton.backgroundColor = isEnabled ? buttonBackgroundColor : disabledButtonBackgroundColor
        }
    }

    // MARK: Actions

    @IBAction func primaryButtonTapped(_ sender: UIButton) {
        if let block = actionBlock {
            block()
        }
    }
}

@available(*, deprecated, message: "Use PrimaryButtonContainer instead, it has the necessary activityIndicator")
public class PrimaryButton: UIButton {

    public override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1.0 : 0.5
            super.alpha = alpha
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        layer.cornerRadius = 4.0
        titleLabel?.font = UIFont(name: Constants.FontNames.montserratMedium, size: 20.0)
        backgroundColor = UIColor.brandSecondary
    }

    override public func setTitle(_ title: String?, for state: UIControl.State) {
        super.setTitle(title, for: state)
        titleLabel?.text = title
    }
}
