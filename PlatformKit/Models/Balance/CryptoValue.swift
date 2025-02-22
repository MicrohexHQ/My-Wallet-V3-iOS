//
//  CryptoValue.swift
//  Blockchain
//
//  Created by Chris Arriola on 12/5/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import BigInt

public struct CryptoComparisonError: Error {
    let currencyType1: CryptoCurrency
    let currencyType2: CryptoCurrency
}

public protocol Crypto: Money {
    var currencyType: CryptoCurrency { get }
    
    /// The amount is the smallest unit of the currency (i.e. satoshi for BTC, wei for ETH, etc.)
    /// a.k.a. the minor value of the currency
    var amount: BigInt { get }
    var value: CryptoValue { get }
}

extension Crypto {
    public var currencyCode: String {
        return value.currencyCode
    }
    
    public var isZero: Bool {
        return value.isZero
    }
    
    public var isPositive: Bool {
        return value.isPositive
    }
    
    public var symbol: String {
        return value.symbol
    }
    
    public var maxDecimalPlaces: Int {
        return value.maxDecimalPlaces
    }
    
    public var maxDisplayableDecimalPlaces: Int {
        return value.maxDisplayableDecimalPlaces
    }
    
    public var currencyType: CryptoCurrency {
        return value.currencyType
    }
    
    public var amount: BigInt {
        return value.amount
    }
    
    public func toDisplayString(includeSymbol: Bool, locale: Locale) -> String {
        return value.toDisplayString(includeSymbol: includeSymbol, locale: locale)
    }
}

public struct CryptoValue: Crypto {
    public let currencyType: CryptoCurrency
    
    /// The amount is the smallest unit of the currency (i.e. satoshi for BTC, wei for ETH, etc.)
    /// a.k.a. the minor value of the currency
    public let amount: BigInt
    
    public var value: CryptoValue {
        return self
    }
    
    private init(currencyType: CryptoCurrency, amount: BigInt) {
        self.currencyType = currencyType
        self.amount = amount
    }
}

// MARK: - Money

extension CryptoValue: Money {
    
    public var currencyCode: String {
        return self.currencyType.symbol
    }
    
    public var isZero: Bool {
        return amount.isZero
    }
    
    public var isPositive: Bool {
        return amount.sign == .plus
    }
    
    /// The symbol for the money (e.g. "BTC", "ETH", etc.)
    public var symbol: String {
        return self.currencyType.symbol
    }
    
    /// The maximum number of decimal places supported by the money
    public var maxDecimalPlaces: Int {
        return self.currencyType.maxDecimalPlaces
    }
    
    /// The maximum number of displayable decimal places.
    public var maxDisplayableDecimalPlaces: Int {
        return self.currencyType.maxDisplayableDecimalPlaces
    }
    
    /// Converts this money to a displayable String in its major format
    ///
    /// - Parameter includeSymbol: whether or not the symbol should be included in the string
    /// - Returns: the displayable String
    public func toDisplayString(includeSymbol: Bool, locale: Locale = Locale.current) -> String {
        let formatter = CryptoFormatterProvider.shared.formatter(locale: locale, cryptoCurrency: currencyType)
        return formatter.format(value: self, withPrecision: .short, includeSymbol: includeSymbol)
    }
}

// MARK: - Operators

extension CryptoValue: Hashable, Equatable {
    private static func ensureComparable(value: CryptoValue, other: CryptoValue) throws {
        if value.currencyType != other.currencyType {
            throw CryptoComparisonError(currencyType1: value.currencyType, currencyType2: other.currencyType)
        }
    }
    
    public static func + (lhs: CryptoValue, rhs: CryptoValue) throws -> CryptoValue {
        try ensureComparable(value: lhs, other: rhs)
        return CryptoValue(currencyType: lhs.currencyType, amount: lhs.amount + rhs.amount)
    }
    
    public static func - (lhs: CryptoValue, rhs: CryptoValue) throws -> CryptoValue {
        try ensureComparable(value: lhs, other: rhs)
        return CryptoValue(currencyType: lhs.currencyType, amount: lhs.amount - rhs.amount)
    }
    
    public static func * (lhs: CryptoValue, rhs: CryptoValue) throws -> CryptoValue {
        try ensureComparable(value: lhs, other: rhs)
        return CryptoValue(currencyType: lhs.currencyType, amount: lhs.amount * rhs.amount)
    }
    
    public static func / (lhs: CryptoValue, rhs: CryptoValue) throws -> CryptoValue {
        try ensureComparable(value: lhs, other: rhs)
        return CryptoValue(currencyType: lhs.currencyType, amount: lhs.amount / rhs.amount)
    }
    
    public static func > (lhs: CryptoValue, rhs: CryptoValue) throws -> Bool {
        try ensureComparable(value: lhs, other: rhs)
        return lhs.amount > rhs.amount
    }
    
    public static func < (lhs: CryptoValue, rhs: CryptoValue) throws -> Bool {
        try ensureComparable(value: lhs, other: rhs)
        return lhs.amount < rhs.amount
    }
    
    public static func >= (lhs: CryptoValue, rhs: CryptoValue) throws -> Bool {
        try ensureComparable(value: lhs, other: rhs)
        return lhs.amount >= rhs.amount
    }
    
    public static func <= (lhs: CryptoValue, rhs: CryptoValue) throws -> Bool {
        try ensureComparable(value: lhs, other: rhs)
        return lhs.amount <= rhs.amount
    }
    
    public static func += (lhs: inout CryptoValue, rhs: CryptoValue) throws {
        lhs = try lhs + rhs
    }
    
    public static func -= (lhs: inout CryptoValue, rhs: CryptoValue) throws {
        lhs = try lhs - rhs
    }
    
    public static func *= (lhs: inout CryptoValue, rhs: CryptoValue) throws {
        lhs = try lhs * rhs
    }
}

// MARK: - Shared

extension CryptoValue {
    /// The major value of the crypto (e.g. BTC, ETH, etc.)
    public var majorValue: Decimal {
        let divisor = BigInt(10).power(currencyType.maxDecimalPlaces)
        let majorValue = amount.decimalDivision(divisor: divisor)
        return majorValue.roundTo(places: currencyType.maxDecimalPlaces)
    }
    
    public static func zero(assetType: CryptoCurrency) -> CryptoValue {
        return CryptoValue(currencyType: assetType, amount: 0)
    }
    
    public static func createFromMinorValue(_ value: BigInt, assetType: CryptoCurrency) -> CryptoValue {
        return CryptoValue(currencyType: assetType, amount: value)
    }

    public static func createFromMajorValue(string value: String, assetType: CryptoCurrency, locale: Locale = Locale.current) -> CryptoValue? {
        guard let valueDecimal = Decimal(string: value, locale: locale) else {
            return nil
        }
        let minorDecimal = valueDecimal * pow(10, assetType.maxDecimalPlaces)
        return CryptoValue(currencyType: assetType, amount: BigInt(stringLiteral: "\(minorDecimal.roundTo(places: 0))"))
    }

    @available(*, deprecated, message: "This method can create precision errors. Use `createFromMajorValue(string:assetType:)` instead.")
    public static func createFromMajorValue(decimal value: Decimal, assetType: CryptoCurrency) -> CryptoValue {
        let decimalNumberValue = NSDecimalNumber(decimal: value)
        let doubleValue = Double(truncating: decimalNumberValue)
        let decimalValue = doubleValue.truncatingRemainder(dividingBy: 1) * pow(10.0, Double(assetType.maxDecimalPlaces))
        let mantissaValue = BigInt(Int(floor(doubleValue))) * BigInt(10).power(assetType.maxDecimalPlaces)
        let amount = mantissaValue + BigInt(decimalValue)
        return CryptoValue(currencyType: assetType, amount: amount)
    }

    public func convertToFiatValue(exchangeRate: FiatValue) -> FiatValue {
        let conversionAmount = majorValue * exchangeRate.amount
        return FiatValue.create(amount: conversionAmount, currencyCode: exchangeRate.currencyCode)
    }
}

// MARK: - Bitcoin

extension CryptoValue {
    public static var bitcoinZero: CryptoValue {
        return zero(assetType: .bitcoin)
    }
    
    public static func bitcoinFromSatoshis(string satoshis: String) -> CryptoValue? {
        guard let satoshiInBigInt = BigInt(satoshis) else {
            return nil
        }
        return CryptoValue(currencyType: .bitcoin, amount: satoshiInBigInt)
    }

    public static func bitcoinFromSatoshis(int satoshis: Int) -> CryptoValue {
        return CryptoValue(currencyType: .bitcoin, amount: BigInt(satoshis))
    }
    
    public static func bitcoinFromMajor(int bitcoin: Int) -> CryptoValue {
        return createFromMajorValue(string: "\(bitcoin)", assetType: .bitcoin)!
    }
    
    @available(*, deprecated, message: "This method can create precision errors. Use `bitcoinFromMajor(string:)` instead.")
    public static func bitcoinFromMajor(decimal bitcoin: Decimal) -> CryptoValue {
        return createFromMajorValue(decimal: bitcoin, assetType: .bitcoin)
    }

    public static func bitcoinFromMajor(string bitcoin: String) -> CryptoValue? {
        return createFromMajorValue(string: bitcoin, assetType: .bitcoin)
    }
}

// MARK: - Ethereum

extension CryptoValue {
    public static var etherZero: CryptoValue {
        return zero(assetType: .ethereum)
    }
    
    public static func etherFromWei(string wei: String) -> CryptoValue? {
        guard let weiInBigInt = BigInt(wei) else {
            return nil
        }
        return CryptoValue(currencyType: .ethereum, amount: weiInBigInt)
    }
    
    public static func etherFromGwei(string gwei: String) -> CryptoValue? {
        guard let gweiInBigInt = BigInt(gwei) else {
            return nil
        }
        let weiInBigInt = gweiInBigInt * BigInt(integerLiteral: 1_000_000_000)
        
        return CryptoValue(currencyType: .ethereum, amount: weiInBigInt)
    }

    public static func etherFromMajor(string ether: String) -> CryptoValue? {
        return createFromMajorValue(string: ether, assetType: .ethereum)
    }
}

// MARK: - Bitcoin Cash

extension CryptoValue {
    public static var bitcoinCashZero: CryptoValue {
        return zero(assetType: .bitcoinCash)
    }
    
    public static func bitcoinCashFromSatoshis(string satoshis: String) -> CryptoValue? {
        guard let satoshiInBigInt = BigInt(satoshis) else {
            return nil
        }
        return CryptoValue(currencyType: .bitcoinCash, amount: satoshiInBigInt)
    }

    public static func bitcoinCashFromSatoshis(int satoshis: Int) -> CryptoValue {
        return CryptoValue(currencyType: .bitcoinCash, amount: BigInt(satoshis))
    }
    
    public static func bitcoinCashFromMajor(int bitcoinCash: Int) -> CryptoValue {
        return createFromMajorValue(string: "\(bitcoinCash)", assetType: .bitcoinCash)!
    }
    
    @available(*, deprecated, message: "This method can create precision errors. Use `bitcoinCashFromMajor(string:)` instead.")
    public static func bitcoinCashFromMajor(decimal bitcoinCash: Decimal) -> CryptoValue {
        return createFromMajorValue(decimal: bitcoinCash, assetType: .bitcoinCash)
    }

    public static func bitcoinCashFromMajor(string bitcoinCash: String) -> CryptoValue? {
        return createFromMajorValue(string: bitcoinCash, assetType: .bitcoinCash)
    }
}

// MARK: - Stellar

extension CryptoValue {
    public static var lumensZero: CryptoValue {
        return zero(assetType: .stellar)
    }
    
    public static func lumensFromStroops(int stroops: Int) -> CryptoValue {
        return CryptoValue(currencyType: .stellar, amount: BigInt(stroops))
    }

    public static func lumensFromStroops(string stroops: String) -> CryptoValue? {
        guard let stroopsInBigInt = BigInt(stroops) else {
            return nil
        }
        return CryptoValue(currencyType: .stellar, amount: stroopsInBigInt)
    }

    public static func lumensFromMajor(int lumens: Int) -> CryptoValue {
        return createFromMajorValue(string: "\(lumens)", assetType: .stellar)!
    }
    
    @available(*, deprecated, message: "This method can create precision errors. Use `lumensFromMajor(string:)` instead.")
    public static func lumensFromMajor(decimal lumens: Decimal) -> CryptoValue {
        return createFromMajorValue(decimal: lumens, assetType: .stellar)
    }

    public static func lumensFromMajor(string lumens: String) -> CryptoValue? {
        return createFromMajorValue(string: lumens, assetType: .stellar)
    }
}

// MARK: - PAX

extension CryptoValue {
    public static var paxZero: CryptoValue {
        return zero(assetType: .pax)
    }
    
    public static func paxFromMajor(string pax: String) -> CryptoValue? {
        return createFromMajorValue(string: pax, assetType: .pax)
    }
}

// MARK: - Number Extensions

extension BigInt {
    func decimalDivision(divisor: BigInt) -> Decimal {
        let (quotient, remainder) =  self.quotientAndRemainder(dividingBy: divisor)
        return Decimal(string: String(quotient))! + Decimal(string: String(remainder))! / Decimal(string: String(divisor))!
    }
}

extension Decimal {
    public var doubleValue: Double {
        return NSDecimalNumber(decimal: self).doubleValue
    }

    func roundTo(places: Int) -> Decimal {
        guard places >= 0 else {
            return self
        }

        let decimalInString = "\(self)"
        guard let peroidIndex = decimalInString.firstIndex(of: ".") else {
            return self
        }

        let startIndex = decimalInString.startIndex
        let maxIndex = decimalInString.endIndex

        if places == 0 {
            let roundedString = String(decimalInString[startIndex..<peroidIndex])
            return Decimal(string: roundedString) ?? self
        }

        guard let endIndex = decimalInString.index(peroidIndex, offsetBy: places+1, limitedBy: maxIndex) else {
            return self
        }
        let roundedString = String(decimalInString[startIndex..<endIndex])
        return Decimal(string: roundedString) ?? self
    }
}
