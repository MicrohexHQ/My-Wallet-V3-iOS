//
//  StellarTransactionService.swift
//  Blockchain
//
//  Created by Alex McGregor on 10/16/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import RxSwift
import stellarsdk
import StellarKit
import PlatformKit

class StellarTransactionService: StellarTransactionAPI {
    
    typealias TransactionResult = StellarTransactionResponse.Result
    typealias StellarAssetType = stellarsdk.AssetType
    typealias StellarTransaction = stellarsdk.Transaction
    
    fileprivate let configuration: StellarConfiguration
    fileprivate let accounts: StellarAccountAPI
    fileprivate let repository: StellarWalletAccountRepository
    fileprivate let walletService: WalletService
    fileprivate lazy var service: stellarsdk.TransactionsService = {
        configuration.sdk.transactions
    }()
    
    init(
        configuration: StellarConfiguration = .production,
        accounts: StellarAccountAPI,
        repository: StellarWalletAccountRepository,
        walletService: WalletService = WalletService.shared
    ) {
        self.configuration = configuration
        self.accounts = accounts
        self.repository = repository
        self.walletService = walletService
    }
    
    func get(transaction transactionHash: String, completion: @escaping ((Result<StellarTransactionResponse, Error>) -> Void)) {
        service.getTransactionDetails(transactionHash: transactionHash) { response -> Void in
            switch response {
            case .success(let details):
                let code = details.transactionResult.code.rawValue
                let result: TransactionResult = code == 0 ? .success : .error(StellarTransactionError(rawValue: Int(code)) ?? .internalError)
                var memo: String?
                if let detailsMemo = details.memo {
                    switch detailsMemo {
                    case .text(let value):
                        memo = value
                    case .id(let value):
                        memo = String(describing: value)
                    default:
                        break
                    }
                }
                
                let value = StellarTransactionResponse(
                    identifier: details.id,
                    result: result,
                    transactionHash: details.transactionHash,
                    createdAt: details.createdAt,
                    sourceAccount: details.sourceAccount,
                    feePaid: details.feePaid,
                    memo: memo
                )
                DispatchQueue.main.async {
                    completion(.success(value))
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func send(_ paymentOperation: StellarPaymentOperation, sourceKeyPair: StellarKit.StellarKeyPair) -> Completable {
        let sourceAccount = accounts.accountResponse(for: sourceKeyPair.accountID)
        return Single.zip(walletService.walletOptions, fundAccountIfEmpty(
            paymentOperation,
            sourceKeyPair: sourceKeyPair
        )).flatMapCompletable { [weak self] walletOptions, didFundAccount in
            guard !didFundAccount else {
                return Completable.empty()
            }
            return sourceAccount.flatMapCompletable { accountResponse -> Completable in
                guard let strongSelf = self else {
                    return Completable.never()
                }
                return strongSelf.send(
                    paymentOperation,
                    accountResponse: accountResponse,
                    sourceKeyPair: sourceKeyPair,
                    timeout: walletOptions.xlmMetadata?.sendTimeOutSeconds
                )
            }
        }
    }

    // MARK: - Private

    private func fundAccountIfEmpty(_ paymentOperation: StellarPaymentOperation, sourceKeyPair: StellarKit.StellarKeyPair) -> Single<Bool> {
        return accounts.accountResponse(for: paymentOperation.destinationAccountId)
            .map { _ in return false }
            .catchError { [weak self] error -> Single<Bool> in
                guard let strongSelf = self else {
                    throw error
                }
                if let stellarError = error as? StellarServiceError, stellarError == .noDefaultAccount {
                    return strongSelf.accounts.fundAccount(
                        paymentOperation.destinationAccountId,
                        amount: paymentOperation.amountInXlm,
                        sourceKeyPair: sourceKeyPair
                    ).andThen(
                        Single.just(true)
                    )
                }
                throw error
            }
    }

    private func send(
        _ paymentOperation: StellarPaymentOperation,
        accountResponse: AccountResponse,
        sourceKeyPair: StellarKit.StellarKeyPair,
        timeout: Int? = nil
    ) -> Completable {
        return Completable.create(subscribe: { [weak self] event -> Disposable in
            guard let strongSelf = self else {
                return Disposables.create()
            }
            do {
                // Assemble objects
                let source = try KeyPair(secretSeed: sourceKeyPair.secret)
                let destination = try KeyPair(accountId: paymentOperation.destinationAccountId)
                let payment = PaymentOperation(
                    sourceAccount: source,
                    destination: destination,
                    asset: Asset(type: StellarAssetType.ASSET_TYPE_NATIVE)!,
                    amount: paymentOperation.amountInXlm
                )
                
                var memo: Memo = .none
                if let value = paymentOperation.memo {
                    switch value {
                    case .text(let input):
                        memo = .text(input)
                    case .identifier(let input):
                        memo = .id(UInt64(input))
                    }
                }
                
                // Use dynamic base fee
                let feeCryptoValue = CryptoValue.lumensFromMajor(decimal: paymentOperation.feeInXlm)
                let baseFeeInStroops = (try? StellarValue(value: feeCryptoValue).stroops()) ?? StellarTransactionFee.defaultLimits.min
                
                var timebounds: TimeBounds?
                let future = Calendar.current.date(
                    byAdding: .second,
                    value: timeout ?? 10,
                    to: Date()
                    )?.timeIntervalSince1970
                
                if let value = future {
                    timebounds = try? TimeBounds(
                        minTime: UInt64(0),
                        maxTime: UInt64(value)
                    )
                }
                
                let transaction = try StellarTransaction(
                    sourceAccount: accountResponse,
                    operations: [payment],
                    baseFee: baseFeeInStroops,
                    memo: memo,
                    timeBounds: timebounds
                )

                // Sign transaction
                try transaction.sign(keyPair: source, network: strongSelf.configuration.network)

                // Perform network operation
                try strongSelf.configuration.sdk.transactions
                    .submitTransaction(transaction: transaction, response: { response -> (Void) in
                        switch response {
                        case .success(details: _):
                            event(.completed)
                        case .failure(let error):
                            event(.error(error.toStellarServiceError()))
                        }
                    })
            } catch {
                event(.error(error))
            }
            return Disposables.create()
        })
    }
    
}
