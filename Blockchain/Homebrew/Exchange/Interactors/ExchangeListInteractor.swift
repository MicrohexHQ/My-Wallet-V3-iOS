//
//  ExchangeListInteractor.swift
//  Blockchain
//
//  Created by Alex McGregor on 8/23/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

class ExchangeListInteractor: ExchangeListInput {
    
    fileprivate let service: ExchangeHistoryAPI
    
    weak var output: ExchangeListOutput?
    
    init(dependencies: ExchangeDependencies) {
        self.service = dependencies.service
    }
    
    func fetchAllTrades() {
        guard service.isExecuting() == false else { return }
        service.getAllTrades { [weak self] (result) in
            switch result {
            case .success(let models):
                self?.output?.loadedTrades(models)
            case .failure(let error):
                self?.output?.tradeFetchFailed(error: error)
            }
        }
    }
    
    func refresh() {
        guard service.isExecuting() == false else { return }
        service.getAllTrades { [weak self] (result) in
            switch result {
            case .success(let models):
                self?.output?.refreshedTrades(models)
            case .failure(let error):
                self?.output?.tradeFetchFailed(error: error)
            }
        }
    }
    
    func canPage() -> Bool {
        return service.canPage
    }
    
    func tradeSelectedWith(identifier: String) -> ExchangeTradeModel? {
        let model = service.tradeModels.filter({ $0.identifier == identifier }).first
        return model
    }
    
    func nextPageBefore(identifier: String) {
        guard service.isExecuting() == false else { return }
        guard let model = service.tradeModels.filter({ $0.identifier == identifier }).first else { return }
        service.getHomebrewTrades(before: model.transactionDate) { [weak self] (result) in
            switch result {
            case .success(let models):
                self?.output?.appendTrades(models)
            case .failure(let error):
                self?.output?.tradeFetchFailed(error: error)
            }
        }
    }
    
    func cancel() {
        guard service.isExecuting() else { return }
        service.cancel()
    }
    
}
