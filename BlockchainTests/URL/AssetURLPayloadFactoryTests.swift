//
//  AssetURLPayloadFactoryTests.swift
//  BlockchainTests
//
//  Created by Chris Arriola on 6/5/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

import XCTest
@testable import Blockchain

class AssetURLPayloadFactoryTests: XCTestCase {

    func testBitcoinURLPayloadCreated() {
        let url = URL(string: "\(BitcoinURLPayload.scheme):address")!
        let payload = AssetURLPayloadFactory.create(from: url)
        XCTAssertNotNil(payload)
        XCTAssertTrue(payload is BitcoinURLPayload)
    }

    func testBitcoinCashURLPayloadCreated() {
        let url = URL(string: "\(BitcoinCashURLPayload.scheme):address")!
        let payload = AssetURLPayloadFactory.create(from: url)
        XCTAssertNotNil(payload)
        XCTAssertTrue(payload is BitcoinCashURLPayload)
    }

    func testStellarURLPayloadCreated() {
        let url = URL(string: "\(StellarURLPayload.scheme):\(StellarURLPayload.payOperation)destination=address")!
        let payload = AssetURLPayloadFactory.create(from: url)
        XCTAssertNotNil(payload)
        XCTAssertTrue(payload is StellarURLPayload)
    }

    func testBitcoinNoFormat() {
        let address = "1Amu4uPJnYbUXX2HhDFMNq7tSneDwWYDyv"
        let payload = AssetURLPayloadFactory.create(fromString: address, assetType: .bitcoin)
        XCTAssertNotNil(payload)
        XCTAssertEqual(address, payload?.address)
    }

    func testBitcoinCashNoFormat() {
        let address = "qzufk542ghfu38582kz5y9kmlsrqfke5esgmzsd3lx"
        let payload = AssetURLPayloadFactory.create(fromString: address, assetType: .bitcoinCash)
        XCTAssertNotNil(payload)
        XCTAssertEqual(address, payload?.address)
    }

    func testStellarNoFormat() {
        let address = "GBNKAL4I5FCITL7BP532VFTFEK3QHPLYHPLFDXGIRYO4GHBDF6QSK243"
        let payload = AssetURLPayloadFactory.create(fromString: address, assetType: .stellar)
        XCTAssertNotNil(payload)
        XCTAssertEqual(address, payload?.address)
    }
}
