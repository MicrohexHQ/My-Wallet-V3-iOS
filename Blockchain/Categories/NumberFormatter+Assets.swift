//
//  NumberFormatter+Assets.swift
//  Blockchain
//
//  Created by kevinwu on 5/2/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

@objc
extension NumberFormatter {

    // MARK: Helper functions
    private static func decimalStyleFormatter(withMinfractionDigits minfractionDigits: Int,
                                              maxfractionDigits: Int,
                                              usesGroupingSeparator: Bool) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = usesGroupingSeparator
        formatter.minimumFractionDigits = minfractionDigits
        formatter.maximumFractionDigits = maxfractionDigits
        return formatter
    }

    // MARK: Local Currency
    static let localCurrencyFractionDigits: Int = 2

    // Example: 1234.12
    static let localCurrencyFormatter: NumberFormatter = {
        return decimalStyleFormatter(withMinfractionDigits: localCurrencyFractionDigits,
                                     maxfractionDigits: localCurrencyFractionDigits,
                                     usesGroupingSeparator: false)
    }()

    // Example: 1,234.12
    static let localCurrencyFormatterWithGroupingSeparator: NumberFormatter = {
        return decimalStyleFormatter(withMinfractionDigits: localCurrencyFractionDigits,
                                     maxfractionDigits: localCurrencyFractionDigits,
                                     usesGroupingSeparator: true)
    }()

    // Used to create QR code string from amount
    static let localCurrencyFormatterWithUSLocale: NumberFormatter = {
        let formatter = decimalStyleFormatter(withMinfractionDigits: localCurrencyFractionDigits,
                                              maxfractionDigits: localCurrencyFractionDigits,
                                              usesGroupingSeparator: false)
        formatter.locale = Locale(identifier: Constants.Locales.englishUS)
        return formatter
    }()

    // MARK: Digital Assets
    static let assetFractionDigits: Int = 8
    static let stellarFractionDigits: Int = 7

    // Example: 1234.12345678
    static let assetFormatter: NumberFormatter = {
        return decimalStyleFormatter(withMinfractionDigits: 0,
                                     maxfractionDigits: assetFractionDigits,
                                     usesGroupingSeparator: false)
    }()

    // TODO: genericize
    static let stellarFormatter: NumberFormatter = {
        return decimalStyleFormatter(withMinfractionDigits: 0,
                                     maxfractionDigits: stellarFractionDigits,
                                     usesGroupingSeparator: false)
    }()

    // Example: 1,234.12345678
    static let assetFormatterWithGroupingSeparator: NumberFormatter = {
        return decimalStyleFormatter(withMinfractionDigits: 0,
                                     maxfractionDigits: assetFractionDigits,
                                     usesGroupingSeparator: true)
    }()

    // Used to create QR code string from amount
    // Used to convert values from returned from APIs
    static let assetFormatterWithUSLocale: NumberFormatter = {
        let formatter = decimalStyleFormatter(withMinfractionDigits: 0,
                                              maxfractionDigits: assetFractionDigits,
                                              usesGroupingSeparator: false)
        formatter.locale = Locale(identifier: Constants.Locales.englishUS)
        return formatter
    }()
}

// MARK: - Conversions
extension NumberFormatter {
    // Returns local currency amount with two decimal places (assuming stringFromNumber returns a string)
    static func localCurrencyAmount(fromAmount: Decimal, fiatPerAmount: Decimal) -> String {
        let conversionResult = fromAmount * fiatPerAmount
        let formatter = NumberFormatter.localCurrencyFormatter
        return formatter.string(from: NSDecimalNumber(decimal: conversionResult)) ?? "\(conversionResult)"
    }

    // Returns asset type amount with correct number of decimal places (currently 7 or 8 depending on asset type) (assuming stringFromNumber returns a string)
    @objc static func assetTypeAmount(
        fromAmount: Decimal,
        fiatPerAmount: Decimal,
        assetType: AssetType
    ) -> String {
        let conversionResult = fromAmount / fiatPerAmount
        let formatter = assetType == .stellar ? NumberFormatter.stellarFormatter : NumberFormatter.assetFormatter
        return formatter.string(from: NSDecimalNumber(decimal: conversionResult)) ?? "\(conversionResult)"
    }
}
