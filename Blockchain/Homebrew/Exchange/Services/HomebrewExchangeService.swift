//
//  HomebrewExchangeService.swift
//  Blockchain
//
//  Created by Alex McGregor on 8/20/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import RxSwift
import PlatformKit

protocol HomebrewExchangeAPI {
    // Currently this filters out trades with an unsupported trading pair.
    func nextPage(fromTimestamp: Date, completion: @escaping ExchangeCompletion)
}

enum HomebrewExchangeServiceError: Error {
    case generic
}

class HomebrewExchangeService: HomebrewExchangeAPI {
    
    fileprivate let authentication: NabuAuthenticationService
    fileprivate var disposable: Disposable?
    
    init(service: NabuAuthenticationService = NabuAuthenticationService.shared) {
        self.authentication = service
    }
    
    deinit {
        disposable?.dispose()
    }

    func nextPage(fromTimestamp: Date, completion: @escaping ExchangeCompletion) {
        
        disposable = trades(before: fromTimestamp)
            .subscribeOn(MainScheduler.asyncInstance)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { (payload) in
                let result: [ExchangeTradeModel] = payload.filter { return $0.pair != nil }.map({ return .homebrew($0) })
                completion(.success(result))
            }, onError: { error in
                completion(.failure(error))
            })
    }
    
    fileprivate func trades(before timestamp: Date) -> Single<[ExchangeTradeCellModel]> {
        guard let baseURL = URL(string: BlockchainAPI.shared.retailCoreUrl) else {
            return .error(HomebrewExchangeServiceError.generic)
        }
        let dateParameter = DateFormatter.iso8601Format.string(from: timestamp)
        let userFiatCurrency = BlockchainSettings.App.shared.fiatCurrencyCode
        guard let endpoint = URL.endpoint(
            baseURL,
            pathComponents: ["trades"],
            queryParameters: ["before": dateParameter, "userFiatCurrency": userFiatCurrency]
        ) else {
            return .error(HomebrewExchangeServiceError.generic)
        }
        
        return authentication.getSessionToken().flatMap { token in
            return NetworkRequest.GET(
                url: endpoint,
                body: nil,
                headers: [HttpHeaderField.authorization: token.token],
                type: [ExchangeTradeCellModel].self
            )
        }
    }
}
