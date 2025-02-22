//
//  XLMServiceProvider.swift
//  Blockchain
//
//  Created by Alex McGregor on 10/22/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import RxSwift
import PlatformKit
import StellarKit

protocol XLMDependencies {
    var accounts: StellarAccountAPI { get }
    var ledger: StellarLedgerService { get }
    var operation: StellarOperationsAPI { get }
    var transaction: StellarTransactionAPI { get }
    var limits: StellarTradeLimitsAPI { get }
    var repository: StellarWalletAccountRepository { get }
    var prices: PriceServiceAPI { get }
    var walletActionEventBus: WalletActionEventBus { get }
    var feeService: StellarFeeServiceAPI { get }
}

struct XLMServices: XLMDependencies {
    var repository: StellarWalletAccountRepository
    var accounts: StellarAccountAPI
    var ledger: StellarLedgerService
    var operation: StellarOperationsAPI
    var transaction: StellarTransactionAPI
    var prices: PriceServiceAPI
    var limits: StellarTradeLimitsAPI
    var walletActionEventBus: WalletActionEventBus
    var feeService: StellarFeeServiceAPI

    init(
        configuration: StellarConfiguration,
        wallet: Wallet = WalletManager.shared.wallet,
        eventBus: WalletActionEventBus = WalletActionEventBus.shared,
        xlmFeeService: StellarFeeServiceAPI = StellarFeeService.shared
    ) {
        walletActionEventBus = eventBus
        repository = StellarWalletAccountRepository(with: wallet)
        ledger = StellarLedgerService(configuration: configuration, feeService: xlmFeeService)
        accounts = StellarAccountService(
            configuration: configuration,
            ledgerService: ledger,
            repository: repository
        )
        transaction = StellarTransactionService(
            configuration: configuration,
            accounts: accounts,
            repository: repository
        )
        operation = StellarOperationService(configuration: configuration, repository: repository)
        prices = PriceServiceClient()
        limits = StellarTradeLimitsService(ledgerService: ledger, accountsService: accounts)
        feeService = xlmFeeService
    }
    
    static let test: XLMServices = XLMServices(configuration: .test)
    static let production: XLMServices = XLMServices(configuration: .production)
}

class XLMServiceProvider: NSObject {
    
    let services: XLMServices
    
    fileprivate let disposables = CompositeDisposable()
    fileprivate var ledger: StellarLedgerService {
        return services.ledger
    }
    fileprivate var accounts: StellarAccountAPI {
        return services.accounts
    }
    
    static let shared = XLMServiceProvider.make()
    
    @objc static func sharedInstance() -> XLMServiceProvider {
        return shared
    }
    
    @objc class func make() -> XLMServiceProvider {
        return XLMServiceProvider(services: .production)
    }
    
    init(services: XLMServices) {
        self.services = services
        super.init()
        setup()
    }

    deinit {
        disposables.dispose()
    }
    fileprivate func setup() {
        let combine = Observable.combineLatest(
            ledger.current,
            accounts.currentStellarAccount(fromCache: false).asObservable()
        ).subscribe()
        disposables.insertWithDiscardableResult(combine)
    }
    
    @objc func tearDown() {
        services.accounts.clear()
        services.operation.clear()
        services.operation.end()
    }
}
