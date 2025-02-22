//
//  AssetType.swift
//  Blockchain
//
//  Created by Maurice A. on 4/13/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import PlatformKit

/// The asset type is used to distinguish between different types of digital assets.
@objc public enum AssetType: Int {
    case bitcoin
    case bitcoinCash
    case ethereum
    case stellar
    case pax
    
    /// Returns `true` if an asset's addresses can be reused
    var shouldAddressesBeReused: Bool {
        return Set<AssetType>([.ethereum, .stellar, .pax]).contains(self)
    }
}

extension AssetType {
    
    /// Returns `true` for a bitcoin cash asset
    var isBitcoinCash: Bool {
        if case .bitcoinCash = self {
            return true
        } else {
            return false
        }
    }
    
    /// Returns `true` for any ERC20 based asset
    var isERC20: Bool {
        switch self {
        case .pax:
            return true
        case .bitcoin, .bitcoinCash, .ethereum, .stellar:
            return false
        }
    }
    
    static let all: [AssetType] = {
        var allAssets: [AssetType] = [.bitcoin, .ethereum, .bitcoinCash]
        if AppFeatureConfigurator.shared.configuration(for: .stellar).isEnabled {
            allAssets.append(.stellar)
        }
        allAssets.append(.pax)
        return allAssets
    }()
    
    static func from(legacyAssetType: LegacyAssetType) -> AssetType {
        return AssetType(from: legacyAssetType)
    }
    
    init(from legacyAssetType: LegacyAssetType) {
        switch legacyAssetType {
        case .bitcoin:
            self = AssetType.bitcoin
        case .bitcoinCash:
            self = AssetType.bitcoinCash
        case .ether:
            self = AssetType.ethereum
        case .stellar:
            self = AssetType.stellar
        case .pax:
            self = AssetType.pax
        }
    }

    init?(stringValue: String) {
        if let value = CryptoCurrency(rawValue: stringValue.uppercased()) {
            self = value.assetType
        } else {
            return nil
        }
    }

    var legacy: LegacyAssetType {
        switch self {
        case .bitcoin:
            return LegacyAssetType.bitcoin
        case .bitcoinCash:
            return LegacyAssetType.bitcoinCash
        case .ethereum:
            return LegacyAssetType.ether
        case .stellar:
            return LegacyAssetType.stellar
        case .pax:
            return LegacyAssetType.pax
        }
    }
    
    /// NOTE: This is used for `ExchangeInputViewModel`.
    /// The view model can provide a `FiatValue` or `CryptoValue`. When
    /// returning a `CryptoValue` we must provide the `CrptoValue`
    var cryptoCurrency: CryptoCurrency {
        return CryptoCurrency(assetType: self)
    }
}

extension AssetType {
    var description: String {
        return CryptoCurrency(assetType: self).description
    }

    var symbol: String {
        return CryptoCurrency(assetType: self).symbol
    }

    var maxDecimalPlaces: Int {
        return CryptoCurrency(assetType: self).maxDecimalPlaces
    }

    var maxDisplayableDecimalPlaces: Int {
        return CryptoCurrency(assetType: self).maxDisplayableDecimalPlaces
    }
    
    // MARK: Filled small image
    
    var filledImageSmallName: String {
        switch self {
        case .bitcoin:
            return "filled_btc_small"
        case .bitcoinCash:
            return "filled_bch_small"
        case .ethereum:
            return "filled_eth_small"
        case .stellar:
            return "filled_xlm_small"
        case .pax:
            return "filled_pax_small"
        }
    }

    var filledImageSmall: UIImage {
        return UIImage(named: filledImageSmallName)!
    }
    
    // MARK: Filled large image
    
    var filledImageLargeName: String {
        switch self {
        case .bitcoin:
            return "filled_btc_large"
        case .bitcoinCash:
            return "filled_bch_large"
        case .ethereum:
            return "filled_eth_large"
        case .stellar:
            return "filled_xlm_large"
        case .pax:
            return "filled_pax_large"
        }
    }
    
    var filledImageLarge: UIImage {
        return UIImage(named: filledImageLargeName)!
    }

    var whiteImageSmall: UIImage {
        switch self {
        case .bitcoin:
            return #imageLiteral(resourceName: "white_btc_small")
        case .bitcoinCash:
            return #imageLiteral(resourceName: "white_bch_small")
        case .ethereum:
            return #imageLiteral(resourceName: "white_eth_small")
        case .stellar:
            return #imageLiteral(resourceName: "white_xlm_small")
        case .pax:
            return #imageLiteral(resourceName: "white_pax_small")
        }
    }

    var symbolImageTemplate: UIImage {
        switch self {
        case .bitcoin:
            return #imageLiteral(resourceName: "symbol-btc")
        case .bitcoinCash:
            return #imageLiteral(resourceName: "symbol-bch")
        case .ethereum:
            return #imageLiteral(resourceName: "symbol-eth")
        case .stellar:
            return #imageLiteral(resourceName: "symbol-xlm")
        case .pax:
            return #imageLiteral(resourceName: "symbol-eth")
        }
    }
    
    var brandColor: UIColor {
        switch self {
        case .bitcoin:
            return UIColor(red: 1, green: 0.61, blue: 0.13, alpha: 1)
        case .ethereum:
            return UIColor(red: 0.28, green: 0.23, blue: 0.8, alpha: 1)
        case .bitcoinCash:
            return UIColor(red: 0.24, green: 0.86, blue: 0.54, alpha: 1)
        case .stellar:
            return UIColor(red: 0.07, green: 0.11, blue: 0.20, alpha: 1)
        case .pax:
            return UIColor(red: 0, green: 0.32, blue: 0.17, alpha: 1)
        }
    }
    
    func toFiat(
        amount: Decimal,
        from wallet: Wallet = WalletManager.shared.wallet
    ) -> String? {
        let input = amount as NSDecimalNumber
        
        switch self {
        case .bitcoin:
            let value = NumberFormatter.parseBtcValue(from: input.stringValue)
            return NumberFormatter.formatMoney(
                value.magnitude,
                localCurrency: true
            )
        case .ethereum:
            let value = NumberFormatter.formatEthToFiat(
                withSymbol: input.stringValue,
                exchangeRate: wallet.latestEthExchangeRate
            )
            return value
        case .bitcoinCash:
            let value = NumberFormatter.parseBtcValue(from: input.stringValue)
            return NumberFormatter.formatBch(
                withSymbol: value.magnitude,
                localCurrency: true
            )
        case .stellar:
            // TODO: add formatting methods
            return "stellar in fiat"
        case .pax:
            // TODO: add formatting methods
            fatalError("Not implemented yet")
        }
    }
    
    func toCrypto(
        amount: Decimal,
        from wallet: Wallet = WalletManager.shared.wallet
    ) -> String? {
        let input = amount as NSDecimalNumber
        switch self {
        case .bitcoin:
            let value = NumberFormatter.parseBtcValue(from: input.stringValue)
            return NumberFormatter.formatMoney(value.magnitude)
        case .ethereum:
            guard let exchangeRate = wallet.latestEthExchangeRate else { return nil }
            return NumberFormatter.formatEth(
                withLocalSymbol: input.stringValue,
                exchangeRate: exchangeRate
            )
        case .bitcoinCash:
            let value = NumberFormatter.parseBtcValue(from: input.stringValue)
            return NumberFormatter.formatBch(withSymbol: value.magnitude)
        case .stellar:
            // TODO: add formatting methods
            return "stellar in crypto"
        case .pax:
            // TODO: add formatting methods
            fatalError("Not implemented yet")
        }
    }
}

extension CryptoCurrency {
    init(assetType: AssetType) {
        switch assetType {
        case .bitcoin:
            self = .bitcoin
        case .bitcoinCash:
            self = .bitcoinCash
        case .ethereum:
            self = .ethereum
        case .stellar:
            self = .stellar
        case .pax:
            self = .pax
        }
    }
    
    var assetType: AssetType {
        switch self {
        case .bitcoin:
            return .bitcoin
        case .bitcoinCash:
            return .bitcoinCash
        case .ethereum:
            return .ethereum
        case .stellar:
            return .stellar
        case .pax:
            return .pax
        }
    }
}

