//
//  WalletService.swift
//  Blockchain
//
//  Created by Chris Arriola on 5/31/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import RxSwift
import PlatformKit

/// Service that interacts with the Blockchain API
@objc class WalletService: NSObject {
    static let shared = WalletService()

    @objc class func sharedInstance() -> WalletService { return shared }

    private let networkManager: NetworkManager
    private let dataRepository: BlockchainDataRepository

    init(
        networkManager: NetworkManager = NetworkManager.shared,
        dataRepository: BlockchainDataRepository = BlockchainDataRepository.shared
    ) {
        self.networkManager = networkManager
        self.dataRepository = dataRepository
    }

    // MARK: - Private Properties

    private var cachedWalletOptions = Variable<WalletOptions?>(nil)

    private var networkFetchedWalletOptions: Single<WalletOptions> {
        return networkManager.requestJsonOrString(
            BlockchainAPI.shared.walletOptionsUrl,
            method: .get
        ).map {
            guard $0.statusCode == 200 else {
                throw NetworkError.generic(message: nil)
            }
            guard let json = $1 as? JSON else {
                throw NetworkError.jsonParseError
            }
            return WalletOptions(json: json)
        }.do(onSuccess: { [weak self] in
            self?.cachedWalletOptions.value = $0
        })
    }

    // MARK: - Public

    /// A Single returning the WalletOptions which contains dynamic flags for configuring the app.
    /// If WalletOptions has already been fetched, this property will return the cached value
    var walletOptions: Single<WalletOptions> {
        return Single.deferred { [unowned self] in
            guard let cachedValue = self.cachedWalletOptions.value else {
                return self.networkFetchedWalletOptions
            }
            return Single.just(cachedValue)
        }
    }
    
    /// Returns true if the provided country code is in the homebrew region
    ///
    /// - Parameter countryCode: the country code
    /// - Returns: a Single returning a boolean indicating whether or not the provided country is
    ///            supported by homebrew
    func isCountryInHomebrewRegion(countryCode: String) -> Single<Bool> {
        return dataRepository.countries.map { countries in
            let kycCountries = countries.filter { $0.isKycSupported }
            return kycCountries.contains(where: { $0.code == countryCode })
        }
    }

    ///  Returns true if the provided country code and state is in the homebrew region
    ///
    /// - Parameters:
    ///   - countryCode: the country code
    ///   - state: the state code if applicable
    /// - Returns: a Single returning a boolean indicating whether or not the provided country code
    ///            and state is supported by a partner
    func isInPartnerRegionForExchange(countryCode: String, state: String?) -> Single<Bool> {
        return walletOptions.map { walletOptions in
            guard let shapeshift = walletOptions.shapeshift else {
                return false
            }

            guard let blacklistedCountries = shapeshift.countriesBlacklist else {
                Logger.shared.warning("Shapeshift countriesBlacklist is nil")
                return false
            }

            guard walletOptions.iosConfig?.showShapeshift ?? false else {
                Logger.shared.warning("Shapeshift is disabled in WalletOptions")
                return false
            }

            let isCountrySupported = !blacklistedCountries.contains(countryCode)

            if let state = state {
                let whitelistedStates = shapeshift.statesWhitelist ?? []
                let isStateSupported = whitelistedStates.contains(state)
                return isCountrySupported && isStateSupported
            } else {
                return isCountrySupported
            }
        }
    }
}

// MARK: - MaintenanceServicing

extension WalletService: MaintenanceServicing {
    /// Returns message for maintenance in case the server is down because of maintenance reasons
    var serverUnderMaintenanceMessage: Single<String?> {
        return walletOptions.map { options in
            if options.downForMaintenance {
                return options.mobileInfo?.message ?? LocalizationConstants.Errors.siteMaintenanceError
            } else {
                return nil
            }
        }
        .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
    }
}

