//
//  TradingPairView.swift
//  Blockchain
//
//  Created by Alex McGregor on 8/30/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformUIKit
import PlatformKit

protocol TradingPairViewDelegate: class {
    func onLeftButtonTapped(_ view: TradingPairView, title: String)
    func onRightButtonTapped(_ view: TradingPairView, title: String)
    func onSwapButtonTapped(_ view: TradingPairView)
}

class TradingPairView: NibBasedView {
    
    static let standardHeight: CGFloat = 62.0
    
    typealias TradingTransitionUpdate = TransitionPresentationUpdate<ViewTransition>
    typealias TradingPresentationUpdate = AnimatablePresentationUpdate<ViewUpdate>
    
    struct Model {
        let transitionUpdate: TradingTransitionUpdate
        let presentationUpdate: TradingPresentationUpdate
    }
    
    enum ViewUpdate: Update {
        case titleColor(UIColor)
        case backgroundColors(left: UIColor, right: UIColor)
        case swapTintColor(UIColor)
    }
    
    enum ViewTransition: Transition {
        case swapImage(UIImage)
        case images(left: UIImage?, right: UIImage?)
        case titles(left: String, right: String)
    }
    
    // MARK: IBOutlets
    
    @IBOutlet fileprivate var leftButton: UIButton!
    @IBOutlet fileprivate var rightButton: UIButton!
    @IBOutlet fileprivate var swapButton: UIButton!
    @IBOutlet fileprivate var exchangeLabel: UILabel!
    @IBOutlet fileprivate var receiveLabel: UILabel!
    
    // MARK: Public
    
    weak var delegate: TradingPairViewDelegate?
    
    // MARK: Lifecycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
        configureButtons()
    }
    
    // MARK: Actions
    
    @IBAction func leftButtonTapped(_ sender: UIButton) {
        delegate?.onLeftButtonTapped(self, title: sender.titleLabel?.text ?? "")
    }
    
    @IBAction func rightButtonTapped(_ sender: UIButton) {
        delegate?.onRightButtonTapped(self, title: sender.titleLabel?.text ?? "")
    }
    
    @IBAction func swapButtonTapped(_ sender: UIButton) {
        delegate?.onSwapButtonTapped(self)
    }
    
    // MARK: Public
    
    func apply(model: Model) {
        apply(presentationUpdate: model.presentationUpdate)
        apply(transitionUpdate: model.transitionUpdate)
    }
    
    func apply(pair: TradingPair, animation: AnimationParameter = .none, transition: TransitionParameter = .none) {
        let presentationUpdate = TradingPresentationUpdate(
            animations: [
                .backgroundColors(left: pair.from.brandColor, right: pair.to.brandColor),
                .swapTintColor(.grayBlue)
            ],
            animation: animation
        )
        
        let transitionUpdate = TradingTransitionUpdate(
            transitions: [
                .images(left: pair.from.whiteImageSmall, right: pair.to.whiteImageSmall),
                .titles(left: pair.from.description, right: pair.to.description),
                .swapImage(#imageLiteral(resourceName: "trading-pair-arrow").withRenderingMode(.alwaysTemplate))
            ],
            transition: transition
        )
        
        apply(presentationUpdate: presentationUpdate)
        apply(transitionUpdate: transitionUpdate)
    }
    
    func apply(presentationUpdate: TradingPresentationUpdate) {
        presentationUpdate.animationType.perform(animations: { [weak self] in
            guard let this = self else { return }
            presentationUpdate.animations.forEach({ this.handle($0) })
        })
    }
    
    func apply(transitionUpdate: TradingTransitionUpdate) {
        transitionUpdate.transitionType.perform(with: self, animations: { [weak self] in
            guard let this = self else { return }
            transitionUpdate.transitions.forEach({ this.handle($0) })
        })
    }
    
    // MARK: Private
    
    fileprivate func handle(_ update: ViewUpdate) {
        switch update {
        case .titleColor(let color):
            exchangeLabel.textColor = color
            receiveLabel.textColor = color
            
        case .backgroundColors(left: let leftColor, right: let rightColor):
            leftButton.backgroundColor = leftColor
            rightButton.backgroundColor = rightColor
            
        case .swapTintColor(let color):
            swapButton.tintColor = color
        }
    }
    
    func handle(_ transition: ViewTransition) {
        switch transition {
        case .swapImage(let image):
            swapButton.setImage(image, for: .normal)
            
        case .images(left: let leftImage, right: let rightImage):
            rightButton.setImage(rightImage, for: .normal)
            leftButton.setImage(leftImage, for: .normal)
            
        case .titles(left: let leftTitle, right: let rightTitle):
            leftButton.setTitle(leftTitle, for: .normal)
            rightButton.setTitle(rightTitle, for: .normal)
            let leftIdentifier = "." + leftTitle
            let rightIdentifier = "." + rightTitle
            leftButton.accessibilityIdentifier = AccessibilityIdentifiers.TradingPairView.fromLabel + leftIdentifier
            rightButton.accessibilityIdentifier = AccessibilityIdentifiers.TradingPairView.toLabel + rightIdentifier
        }
    }

    func configureButtons() {
        leftButton.layer.cornerRadius = Constants.Measurements.buttonCornerRadius
        rightButton.layer.cornerRadius = Constants.Measurements.buttonCornerRadius

        let numberOfLines = 1
        leftButton.titleLabel?.numberOfLines = numberOfLines
        rightButton.titleLabel?.numberOfLines = numberOfLines

        let edgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        leftButton.titleEdgeInsets = edgeInsets
        rightButton.titleEdgeInsets = edgeInsets

        let swapImage = #imageLiteral(resourceName: "trading-pair-arrow").withRenderingMode(.alwaysTemplate)
        swapButton.setImage(swapImage, for: .normal)
        
        let isAboveSE = UIDevice.current.type.isAbove(.iPhoneSE)
        var font: Font
        switch isAboveSE {
        case true:
            font = Font(.branded(.montserratRegular), size: .custom(16.0))
        case false:
            font = Font(.branded(.montserratRegular), size: .custom(12.0))
        }
        leftButton.titleLabel?.font = font.result
        rightButton.titleLabel?.font = font.result
    }
}

extension TradingPairView {
    
    static func exchangeLockedModel(for trade: Trade) -> Model {
        let fromAsset = trade.pair.from
        let toAsset = trade.pair.to

        // TODO: Some of the data below is placeholder data
        // and will be adjusted once this is hooked up with a live
        // API. In the mean time, this demonstrates how the Model
        // is built and how it is to be used for the exchangeLocked screen
        let transitionUpdate = TradingTransitionUpdate(
            transitions: [.swapImage(#imageLiteral(resourceName: "trading-pair-arrow")),
                          .images(left: fromAsset.whiteImageSmall, right: toAsset.whiteImageSmall),
                          .titles(left: "123 BTC", right: "123 ETH")
            ],
            transition: .none
        )
        
        let presentationUpdate = TradingPresentationUpdate(
            animations: [
                .backgroundColors(left: fromAsset.brandColor, right: toAsset.brandColor),
                .swapTintColor(#colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)),
                .titleColor(#colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
            ],
            animation: .none
        )
        
        let model = Model(
            transitionUpdate: transitionUpdate,
            presentationUpdate: presentationUpdate
        )
        return model
    }
    
    static func confirmationModel(for conversion: Conversion) -> Model {
        guard let pair = TradingPair(string: conversion.quote.pair) else {
            Logger.shared.error("Couldn't create trading pair from conversion")
            let transitionUpdate = TradingTransitionUpdate(
                transitions: [],
                transition: .none
            )
            let presentationUpdate = TradingPresentationUpdate(
                animations: [],
                animation: .none
            )
            return Model(
                transitionUpdate: transitionUpdate,
                presentationUpdate: presentationUpdate
            )
        }

        let fromAsset = pair.from
        let toAsset = pair.to

        let currencyRatio = conversion.quote.currencyRatio

        let fromAmount = currencyRatio.base.crypto.value
        let fromSymbol = currencyRatio.base.crypto.symbol
        let fromAmountAndSymbol = fromAmount + " " + fromSymbol

        let toAmount = currencyRatio.counter.crypto.value
        let toSymbol = currencyRatio.counter.crypto.symbol
        let toAmountAndSymbol = toAmount + " " + toSymbol

        let transitionUpdate = TradingTransitionUpdate(
            transitions: [.swapImage(#imageLiteral(resourceName: "trading-pair-arrow")),
                          .images(left: nil, right: nil),
                          .titles(left: fromAmountAndSymbol, right: toAmountAndSymbol)
            ],
            transition: .none
        )
        
        let presentationUpdate = TradingPresentationUpdate(
            animations: [
                .backgroundColors(left: fromAsset.brandColor, right: toAsset.brandColor),
                .swapTintColor(.brandPrimary),
                .titleColor(.brandPrimary)
            ],
            animation: .none
        )
        
        let model = Model(
            transitionUpdate: transitionUpdate,
            presentationUpdate: presentationUpdate
        )
        return model
    }
    
}
