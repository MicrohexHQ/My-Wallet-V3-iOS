//
//  SocketMessage.swift
//  Blockchain
//
//  Created by kevinwu on 8/3/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import PlatformKit
import BigInt

// TICKET: IOS-1318
// Move structs into separate files

enum SocketType: String {
    case unassigned
    case exchange
    case bitcoin
    case ether
    case bitcoinCash

    static let all: [SocketType] = [
        .unassigned,
        .exchange,
        .bitcoin,
        .ether,
        .bitcoinCash
    ]
}

struct SocketMessage {
    let type: SocketType
    let JSONMessage: Codable
}

protocol SocketMessageCodable: Codable {
    associatedtype JSONType: Codable
    static func tryToDecode(
        socketType: SocketType,
        data: Data,
        onSuccess: (SocketMessage) -> Void,
        onError: (String) -> Void
    )
}

extension SocketMessageCodable {
    static func tryToDecode(
        socketType: SocketType,
        data: Data,
        onSuccess: (SocketMessage) -> Void,
        onError: (String) -> Void
    ) {
        do {
            let decoded = try JSONType.decode(data: data)
            let socketMessage = SocketMessage(type: socketType, JSONMessage: decoded)
            onSuccess(socketMessage)
            return
        } catch {
            onError("Could not decode: \(error)")
        }
    }
}

// TODO: consider separate files when other socket types are added
// TODO: add tests when parameters are figured out

// MARK: - Subscribing
struct Subscription<SubscribeParams: Codable>: SocketMessageCodable {
    typealias JSONType = Subscription
    
    let channel: String
    let action = "subscribe"
    let params: SubscribeParams

    private enum CodingKeys: CodingKey {
        case channel
        case action
        case params
    }
}

struct AuthSubscribeParams: Codable {
    let type: String
    let token: String
}

struct ConversionSubscribeParams: Codable {
    let type: String
    let pair: String
    let fiatCurrency: String
    let fix: Fix
    let volume: String
    
    init(type: String, pair: String, fiatCurrency: String, fix: Fix, volume: String) {
        self.type = type
        self.pair = pair
        self.fiatCurrency = fiatCurrency
        self.fix = fix
        let formatted = volume.components(separatedBy: Locale.current.decimalSeparator ?? ".")
        self.volume = formatted.joined(separator: ".")
    }
}

struct AllCurrencyPairsUnsubscribeParams: Codable {
    let type = "allCurrencyPairs"
}

struct CurrencyPairsSubscribeParams: Codable {
    let type = "exchangeRates"
    let pairs: [String]
}

// MARK: - Unsubscribing

struct Unsubscription<UnsubscribeParams: Codable>: SocketMessageCodable {
    typealias JSONType = Unsubscription

    let channel: String
    let action = "unsubscribe"
    let params: UnsubscribeParams
}

struct ConversionPairUnsubscribeParams: Codable {
    let type = "conversionPair"
    let pair: String
}

// MARK: - Received Messages

struct ExchangeRates: SocketMessageCodable {
    typealias JSONType = ExchangeRates

    let seqnum: Int
    let channel: String
    let event: String
    let rates: [CurrencyPairRate]
}

extension ExchangeRates {
    func convert(balance: CryptoValue, toCurrency: String) -> FiatValue {
        let fromCurrency = balance.currencyType.symbol
        if let matchingPair = pairRate(fromCurrency: fromCurrency, toCurrency: toCurrency) {
            let price: BigInt = BigInt(string: matchingPair.price, unitDecimals: 2) ?? 1
            let conversion = price * balance.amount
            let amountString = conversion.string(unitDecimals: balance.currencyType.maxDecimalPlaces + 2)
            return FiatValue.create(amountString: amountString, currencyCode: toCurrency)
        }
        return FiatValue.zero(currencyCode: toCurrency)
    }

    func pairRate(fromCurrency: String, toCurrency: String) -> CurrencyPairRate? {
        return rates.first(where: { $0.pair == "\(fromCurrency)-\(toCurrency)" })
    }
}

struct HeartBeat: SocketMessageCodable {
    typealias JSONType = HeartBeat
    
    let seqnum: Int
    let channel: String
    let event: String
    
    private enum CodingKeys: String, CodingKey {
        case seqnum
        case channel
        case event
    }
}

struct Conversion: SocketMessageCodable {
    typealias JSONType = Conversion

    let seqnum: Int
    let channel: String
    let event: String
    let quote: Quote

    private enum CodingKeys: CodingKey {
        case seqnum
        case channel
        case event
        case quote
    }
}

extension Conversion: Equatable {
    static func == (lhs: Conversion, rhs: Conversion) -> Bool {
        return lhs.channel == rhs.channel &&
        lhs.event == rhs.event &&
        lhs.quote == rhs.quote
    }
}

extension Conversion {
    
    var baseFiatSymbol: String {
        return quote.currencyRatio.base.fiat.symbol
    }
    
    var baseFiatValue: String {
        return quote.currencyRatio.base.fiat.value
    }
    
    var baseCryptoSymbol: String {
        return quote.currencyRatio.base.crypto.symbol
    }
    
    var baseCryptoValue: String {
        return quote.currencyRatio.base.crypto.value
    }
}

/// `SocketError` is for any type of error that
/// is returned from the WS endpoint. 
struct SocketError: SocketMessageCodable, Error {
    typealias JSONType = SocketError
    
    enum SocketErrorType {
        
        case currencyRatioError
        case `default`
        
        init(rawValue: String) {
            switch rawValue {
            case "currencyRatioError":
                self = .currencyRatioError
            default:
                self = .default
            }
        }
    }

    let errorType: SocketErrorType
    let channel: String
    let description: String
    let code: NabuNetworkErrorCode
    
    private enum CodingKeys: CodingKey {
        case event
        case type
        case channel
        case error
        case code
    }
    
    private enum ErrorKeys: CodingKey {
        case description
        case code
    }
    
    init(channel: String, description: String) {
        self.errorType = .default
        self.channel = channel
        self.description = description
        self.code = .notFound
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        errorType = SocketErrorType(rawValue: type)
        channel = try container.decode(String.self, forKey: .channel)
        let errorContainer = try container.nestedContainer(keyedBy: ErrorKeys.self, forKey: .error)
        description = try errorContainer.decode(String.self, forKey: .description)
        code = try errorContainer.decode(NabuNetworkErrorCode.self, forKey: .code)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(errorType.rawValue, forKey: .event)
        try container.encode(channel, forKey: .channel)
        var errorContainer = container.nestedContainer(keyedBy: ErrorKeys.self, forKey: .error)
        try errorContainer.encode(description, forKey: .description)
        try errorContainer.encode(code, forKey: .code)
    }
}

extension SocketError {
    static let generic: SocketError = SocketError(channel: "unknown", description: "unknown")
}

extension SocketError.SocketErrorType {
    
    var rawValue: String {
        switch self {
        case .currencyRatioError:
            return "currencyRatioError"
        case .default:
            return "default"
        }
    }
}

// MARK: - Associated Models

struct CurrencyPairRate: Codable {
    let pair: String
    let price: String

    enum CodingKeys: String, CodingKey {
        case pair
        case price
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pair = try container.decode(String.self, forKey: .pair)
        price = try container.decode(String.self, forKey: .price)
    }
}

struct Quote: Codable {
    let time: String?
    let pair: String
    let fiatCurrency: String
    let fix: Fix
    let volume: String
    let currencyRatio: CurrencyRatio
}

extension Quote: Equatable {
    static func == (lhs: Quote, rhs: Quote) -> Bool {
        return lhs.pair == rhs.pair &&
        lhs.fiatCurrency == rhs.fiatCurrency &&
        lhs.fix == rhs.fix &&
        lhs.volume == rhs.volume &&
        lhs.currencyRatio == rhs.currencyRatio
    }
}

struct CurrencyRatio: Codable {
    let base: FiatCrypto
    let counter: FiatCrypto
    let baseToFiatRate: String
    let baseToCounterRate: String
    let counterToBaseRate: String
    let counterToFiatRate: String
}

extension CurrencyRatio: Equatable {
    static func == (lhs: CurrencyRatio, rhs: CurrencyRatio) -> Bool {
        return lhs.base == rhs.base &&
        lhs.counter == rhs.counter &&
        lhs.baseToFiatRate == rhs.baseToFiatRate &&
        lhs.counterToBaseRate == rhs.counterToBaseRate &&
        lhs.counterToFiatRate == rhs.counterToFiatRate
    }
}

struct FiatCrypto: Codable {
    let fiat: SymbolValue
    let crypto: SymbolValue
}

extension FiatCrypto: Equatable {
    static func == (lhs: FiatCrypto, rhs: FiatCrypto) -> Bool {
        return lhs.fiat.symbol == rhs.fiat.symbol &&
            lhs.fiat.value == rhs.fiat.value &&
            lhs.crypto.value == rhs.crypto.value &&
            lhs.crypto.symbol == rhs.crypto.symbol
    }
}

struct SymbolValue: Codable {
    let symbol: String
    let value: String
}
