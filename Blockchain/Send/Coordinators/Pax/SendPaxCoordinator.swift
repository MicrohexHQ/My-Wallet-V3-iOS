//
//  SendPaxCoordinator.swift
//  Blockchain
//
//  Created by AlexM on 5/10/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import PlatformKit
import EthereumKit
import BigInt
import ERC20Kit

class SendPaxCoordinator {
    
    fileprivate let interface: SendPAXInterface
    fileprivate let serviceProvider: PAXServiceProvider
    fileprivate var services: PAXServices {
        return serviceProvider.services
    }
    
    fileprivate let bag: DisposeBag = DisposeBag()
    
    fileprivate let calculator: SendPaxCalculator
    fileprivate let priceAPI: PriceServiceAPI
    fileprivate var isExecuting: Bool = false
    fileprivate var output: SendPaxOutput?
    private let pitAddressFetcher: PitAddressFetching
    
    /// The source of the address
    private var addressSource = SendAssetAddressSource.standard
    
    /// The pit address
    private var pitAddress: String!

    private var fees: Single<EthereumTransactionFee> {
        return services.feeService.fees
    }
    
    init(
        interface: SendPAXInterface,
        serviceProvider: PAXServiceProvider = PAXServiceProvider.shared,
        priceService: PriceServiceAPI = PriceServiceClient(),
        pitAddressFetcher: PitAddressFetching = PitAddressFetcher()
    ) {
        self.interface = interface
        self.calculator = SendPaxCalculator(erc20Service: serviceProvider.services.paxService)
        self.serviceProvider = serviceProvider
        self.priceAPI = priceService
        self.pitAddressFetcher = pitAddressFetcher
        if let controller = interface as? SendPaxViewController {
            controller.delegate = self
        }
    }
}

// MARK: - Private

extension SendPaxCoordinator {
    
    // TODO: Should be calculated inside SendPaxCalculator. Add unit-test!
    /// Contains raw data about fiat, ether, pax and ERC20 account balance
    private struct Metadata {
        let etherInFiat: FiatValue
        let paxInFiat: FiatValue
        let etherFee: CryptoValue?
        let balance: CryptoValue?

        var fiatFee: FiatValue? {
            return etherFee?.convertToFiatValue(exchangeRate: etherInFiat)
        }
        
        var paxFee: CryptoValue? {
            return fiatFee?.convertToCryptoValue(exchangeRate: paxInFiat, cryptoCurrency: .pax)
        }
        
        init(etherInFiat: FiatValue, paxInFiat: FiatValue, etherFee: EthereumTransactionFee, balance: CryptoValue) {
            self.etherInFiat = etherInFiat
            self.paxInFiat = paxInFiat
            
            let gasPrice = BigUInt(etherFee.priority.amount)
            let gasLimit = BigUInt(etherFee.gasLimitContract)
            let fee = gasPrice * gasLimit
            self.etherFee = CryptoValue.etherFromWei(string: "\(fee)")
            self.balance = balance
        }
        
        func displayData(using erc20Value: CryptoValue? = nil) -> DisplayData {
            // Calculate fees
            let fiatFee = self.fiatFee
            let fiatDisplayFee = fiatFee?.toDisplayString(includeSymbol: true) ?? ""
            let etherDisplayFee = etherFee?.toDisplayString(includeSymbol: true) ?? ""
            let displayFee = "\(etherDisplayFee) (\(fiatDisplayFee))"
            
            // Calculate transaction value
            let cryptoAmount = erc20Value?.toDisplayString(includeSymbol: true) ?? ""
            let fiatValue = erc20Value?.convertToFiatValue(exchangeRate: paxInFiat)
            let fiatAmount = fiatValue?.toDisplayString(includeSymbol: true) ?? ""

            let totalFiatDisplayValue: String
            if let fiatFee = fiatFee, let fiatValue = fiatValue, let totalFiatIncludingFee = try? fiatValue + fiatFee {
                totalFiatDisplayValue = totalFiatIncludingFee.toDisplayString(includeSymbol: true)
            } else {
                totalFiatDisplayValue = ""
            }
            
            let totalCryptoDisplayValue: String
            if let cryptoValue = erc20Value, let cryptoFee = paxFee, let totalCryptoIncludingFee = try? cryptoValue + cryptoFee {
                totalCryptoDisplayValue = totalCryptoIncludingFee.toDisplayString(includeSymbol: true)
            } else {
                totalCryptoDisplayValue = ""
            }
    
            return DisplayData(fee: displayFee,
                               cryptoAmount: cryptoAmount,
                               fiatAmount: fiatAmount,
                               totalFiatIncludingFee: totalFiatDisplayValue,
                               totalCryptoIncludingFee: totalCryptoDisplayValue)
        }
    }
    
    /// Aggregates the data ready for display.
    private struct DisplayData {
        let fee: String
        let cryptoAmount: String
        let fiatAmount: String
        
        var totalFiatIncludingFee: String
        var totalCryptoIncludingFee: String
        
        var totalAmount: String {
            return "\(cryptoAmount) (\(fiatAmount))"
        }
    }
    
    /// Returns metadata struct. See `Metadata`.
    private var metadata: Single<Metadata> {
        let balance = services.assetAccountRepository.assetAccountDetails
            .map { details -> CryptoValue in
                return details.balance
            }
            .subscribeOn(MainScheduler.asyncInstance)
            .asObservable()
            .asSingle()

        let currencyCode = BlockchainSettings.App.shared.fiatCurrencyCode
        return Single.zip(
            priceAPI.fiatPrice(forCurrency: .ethereum, fiatSymbol: currencyCode),
            priceAPI.fiatPrice(forCurrency: .pax, fiatSymbol: currencyCode),
            fees,
            balance
        )
        .map { (ethPrice, paxPrice, etherTransactionFee, balance) -> Metadata in
            return Metadata(etherInFiat: ethPrice.priceInFiat,
                                   paxInFiat: paxPrice.priceInFiat,
                                   etherFee: etherTransactionFee,
                                   balance: balance)
        }
    }
    
    /// Fetches updated transaction and fee amounts for display purpose
    private var displayData: Single<DisplayData?> {
        return metadata
            .map { [weak self] data in
                return data.displayData(using: self?.output?.model.proposal?.value.value)
            }
            .observeOn(MainScheduler.asyncInstance)
    }
}

extension SendPaxCoordinator: SendPaxViewControllerDelegate {
    var rightNavigationCTAType: NavigationCTAType {
        guard isExecuting == false else { return .activityIndicator }
        return output?.model.internalError != nil ? .error : .qrCode
    }
    
    func onLoad() {
        interface.apply(updates: [.maxAvailable(nil),
                                  .pitAddressButtonVisibility(false),
                                  .usePitAddress(nil)])

        // Fetch the PIT address for PAX asset and apply changes to the interface
        pitAddressFetcher.fetchAddress(for: .pax)
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] address in
                guard let self = self else { return }
                self.pitAddress = address
                self.interface.apply(updates: [.pitAddressButtonVisibility(true)])
            }, onError: { [weak self] error in
                self?.interface.apply(updates: [.pitAddressButtonVisibility(false)])
            })
            .disposed(by: bag)
        
        // Load any pending send metadata and prefill
        calculator.status
            .subscribeOn(MainScheduler.instance)
            .observeOn(MainScheduler.asyncInstance)
            .do(onNext: { [weak self] status in
                guard let self = self else { return }
                self.isExecuting = status == .executing
                self.interface.apply(updates: [.updateNavigationItems])
            })
            .subscribe()
            .disposed(by: bag)
        
        calculator.output
            .subscribeOn(MainScheduler.instance)
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] result in
                guard let self = self else { return }
                self.output = result
                self.interface.apply(updates: result.presentationUpdates)
            }, onError: { error in
                Logger.shared.error(error)
            })
            .disposed(by: bag)
        
        calculator.handle(event: .start)
    }
    
    func onAppear() {
        
        serviceProvider.services.walletService.fetchHistoryIfNeeded
            .subscribe()
            .disposed(by: bag)
        calculator.handle(event: .resume)
        
        let fiatCurrencyCode = BlockchainSettings.App.shared.fiatCurrencyCode
        interface.apply(updates: [.fiatCurrencyLabel(fiatCurrencyCode)])
        
        // TODO: Check ETH balance to cover fees. Only fees.
        // Don't care how much PAX they are sending.
        
        metadata
            .observeOn(MainScheduler.instance)
            .do(onSuccess: { [weak self] data in
                self?.interface.apply(updates: [.maxAvailable(data.balance)])
            })
            .map { return $0.displayData() }
            .subscribe(onSuccess: { [weak self] data in
                self?.interface.apply(updates: [.feeValueLabel(data.fee)])
            }, onError: { error in
                Logger.shared.error(error)
            })
            .disposed(by: bag)
    }
    
    // TODO: Should be ERCTokenValue
    func onPaxEntry(_ value: CryptoValue?) {
        // TODO: Build transaction
        // swiftlint:disable force_try
        let tokenValue = try! ERC20TokenValue<PaxToken>.init(crypto: value ?? .paxZero)
        calculator.handle(event: .paxValueEntryEvent(tokenValue))
    }
    
    func onFiatEntry(_ value: FiatValue) {
        // TODO: Build transaction
        // TODO: Validate against balance
        calculator.handle(event: .fiatValueEntryEvent(value))
    }
    
    func onAddressEntry(_ value: String?) {
        guard let accountID = value else { return }
        calculator.handle(event: .addressEntryEvent(accountID))
    }
    
    func onSendProposed() {
        guard let model = output?.model else { return }
        guard let address = model.addressStatus.address else {
            interface.apply(updates: [.showAlertSheetForError(.invalidDestinationAddress)])
            return
        }
        interface.apply(updates: [.loadingIndicatorVisibility(.visible)])
        
        let displayAddress: String
        switch addressSource {
        case .pit:
            displayAddress = String(format: LocalizationConstants.PIT.Send.destination,
                                    AssetType.pax.symbol)
        case .standard:
            displayAddress = address.rawValue
        }
        
        displayData
            .map { data -> BCConfirmPaymentViewModel in
                let model = BCConfirmPaymentViewModel(
                    from: LocalizationConstants.SendAsset.myPaxWallet,
                    destinationDisplayAddress: displayAddress,
                    destinationRawAddress: address.rawValue,
                    totalAmountText: data?.totalCryptoIncludingFee ?? "",
                    fiatTotalAmountText: data?.totalFiatIncludingFee ?? "",
                    cryptoWithFiatAmountText: data?.totalAmount ?? "",
                    amountWithFiatFeeText: data?.fee ?? "",
                    buttonTitle: LocalizationConstants.SendAsset.send,
                    showDescription: false,
                    surgeIsOccurring: false,
                    showsFeeInformationButton: false,
                    noteText: nil,
                    warningText: nil,
                    descriptionTitle: nil
                )!
                return model
            }
            .subscribe(onSuccess: { [weak self] viewModel in
                self?.interface.display(confirmation: viewModel)
                self?.interface.apply(updates: [.loadingIndicatorVisibility(.hidden)])
            }, onError: { [weak self]  error in
                Logger.shared.error(error)
                self?.interface.apply(updates: [.showAlertSheetForError(SendMoniesInternalError.default)])
            })
            .disposed(by: bag)
    }
    
    func onConfirmSendTapped() {
        guard let model = output?.model else { return }
        guard let proposal = model.proposal else { return }
        guard case .valid(let address) = model.addressStatus else { return }
        interface.apply(updates: [.loadingIndicatorVisibility(.visible)])
        services.paxService.transfer(proposal: proposal, to: address.ethereumAddress)
            .subscribeOn(MainScheduler.instance)
            .observeOn(MainScheduler.asyncInstance)
            .flatMap(weak: self) { (self, candidate) -> Single<EthereumTransactionPublished> in
                return self.services.walletService.send(transaction: candidate)
            }
            .do(onDispose: { [weak self] in
                guard let self = self else { return }
                self.interface.apply(updates: [.loadingIndicatorVisibility(.hidden)])
            })
            .subscribe(onSuccess: { [weak self] published in
                guard let self = self else { return }
                self.calculator.handle(event: .start)
                self.interface.apply(updates: [.hideConfirmationModal,
                                               .toAddressTextField(nil),
                                               .showAlertSheetForSuccess])
                Logger.shared.debug("Published PAX transaction: \(published)")
            }, onError: { [weak self] error in
                Logger.shared.error(error)
                self?.interface.apply(updates: [.showAlertSheetForError(SendMoniesInternalError.default)])
            })
            .disposed(by: bag)
    }
    
    func onErrorBarButtonItemTapped() {
        guard let output = output else { return }
        guard let error = output.model.internalError else { return }
        interface.apply(updates: [.showAlertSheetForError(error)])
    }
    
    func onQRBarButtonItemTapped() {
        interface.displayQRCodeScanner()
    }
    
    func onPitAddressButtonTapped() {
        switch addressSource {
        case .pit:
            addressSource = .standard
            interface.apply(updates: [.usePitAddress(nil)])
        case .standard:
            addressSource = .pit
            onAddressEntry(pitAddress)
            interface.apply(updates: [.usePitAddress(pitAddress)])
        }
    }
}
