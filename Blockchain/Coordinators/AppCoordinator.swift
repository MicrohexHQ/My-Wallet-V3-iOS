//
//  AppCoordinator.swift
//  Blockchain
//
//  Created by Chris Arriola on 4/17/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformUIKit

/**
 Application coordinator.

 This Singleton coordinator is in charge of coordinating the set of views that are
 presented when the app first launches.
*/
@objc class AppCoordinator: NSObject, Coordinator {
    
    // MARK: - Properties

    static let shared = AppCoordinator()

    
    // class function declared so that the AppCoordinator singleton can be accessed from obj-C
    @objc class func sharedInstance() -> AppCoordinator {
        return AppCoordinator.shared
    }

    // MARK: - Services
    
    private(set) var window: UIWindow

    private let walletManager: WalletManager
    private let paymentPresenter: PaymentPresenter
    private let loadingViewPresenter: LoadingViewPresenting
    
    // MARK: - UIViewController Properties

    @objc lazy var slidingViewController: ECSlidingViewController = { [unowned self] in
        let viewController = ECSlidingViewController()
        viewController.underLeftViewController = self.sideMenuViewController
        viewController.topViewController = tabControllerManager
        return viewController
    }()

    @objc lazy var tabControllerManager: TabControllerManager = {
        let tabControllerManager = TabControllerManager.makeFromStoryboard()
        return tabControllerManager
    }()

    private lazy var sideMenuViewController: SideMenuViewController = { [unowned self] in
        let viewController = SideMenuViewController.makeFromStoryboard()
        viewController.delegate = self
        return viewController
    }()

    private lazy var accountsAndAddressesNavigationController: AccountsAndAddressesNavigationController = { [unowned self] in
        let storyboard = UIStoryboard(name: "AccountsAndAddresses", bundle: nil)
        let viewController = storyboard.instantiateViewController(
            withIdentifier: "AccountsAndAddressesNavigationController"
        ) as! AccountsAndAddressesNavigationController
        viewController.modalTransitionStyle = .coverVertical
        return viewController
    }()

    @objc private var settingsNavigationController: SettingsNavigationController?

    // MARK: NSObject

    private init(walletManager: WalletManager = WalletManager.shared,
                 paymentPresenter: PaymentPresenter = PaymentPresenter(),
                 loadingViewPresenter: LoadingViewPresenting = LoadingViewPresenter()) {
        self.walletManager = walletManager
        self.paymentPresenter = paymentPresenter
        self.loadingViewPresenter = loadingViewPresenter
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window.backgroundColor = .white
        super.init()
        self.walletManager.accountInfoAndExchangeRatesDelegate = self
        self.walletManager.backupDelegate = self
        self.walletManager.historyDelegate = self
        observeSymbolChanges()
    }

    // MARK: Public Methods

    @objc func start() {
        // Set rootViewController
        window.rootViewController = slidingViewController
        window.makeKeyAndVisible()
        tabControllerManager.dashBoardClicked(nil)

        AppFeatureConfigurator.shared.initialize()
        BuySellCoordinator.shared.start()

        // Display welcome screen if no wallet is authenticated
        if BlockchainSettings.App.shared.guid == nil || BlockchainSettings.App.shared.sharedKey == nil {
            OnboardingCoordinator.shared.start()
        } else {
            AuthenticationCoordinator.shared.start()
        }
    }

    /// Shows an upgrade to HD wallet prompt if the user has a legacy wallet
    @objc func showHdUpgradeViewIfNeeded() {
        guard walletManager.wallet.isInitialized() else { return }
        guard !walletManager.wallet.didUpgradeToHd() else { return }
        showHdUpgradeView()
    }

    /// Shows the HD wallet upgrade view
    func showHdUpgradeView() {
        let storyboard = UIStoryboard(name: "Upgrade", bundle: nil)
        let upgradeViewController = storyboard.instantiateViewController(withIdentifier: "UpgradeViewController")
        upgradeViewController.modalTransitionStyle = .coverVertical
        UIApplication.shared.keyWindow?.rootViewController?.present(
            upgradeViewController,
            animated: true
        )
    }
    
    // Shows the side menu (i.e. ECSlidingViewController)
    @objc func toggleSideMenu() {
        // If the sideMenu is not shown, show it
        if slidingViewController.currentTopViewPosition == .centered {
            slidingViewController.anchorTopViewToRight(animated: true)
        } else {
            slidingViewController.resetTopView(animated: true)
        }
        
        // TODO remove app reference and use wallet singleton.isFe
        walletManager.wallet.isFetchingTransactions = false
    }

    @objc func showBackupView() {
        let storyboard = UIStoryboard(name: "Backup", bundle: nil)
        let backupController = storyboard.instantiateViewController(withIdentifier: "BackupNavigation") as! BackupNavigationViewController
        backupController.wallet = walletManager.wallet
        backupController.modalTransitionStyle = .coverVertical
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(backupController, animated: true)
    }

    @objc func showSettingsView(completion: ((_ settingViewController: SettingsNavigationController) -> Void)? = nil) {
        let storyboard = UIStoryboard(name: "Settings", bundle: nil)
        let viewController = storyboard.instantiateViewController(
            withIdentifier: "SettingsNavigationController"
        ) as! SettingsNavigationController
        viewController.showSettings()
        viewController.modalTransitionStyle = .coverVertical
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(
            viewController,
            animated: true
        ) {
            completion?(viewController)
        }

        settingsNavigationController = viewController
    }

    @objc func closeSideMenu() {
        guard slidingViewController.currentTopViewPosition != .centered else {
            return
        }
        slidingViewController.resetTopView(animated: true)
    }

    /// Reloads contained view controllers
    @objc func reload() {
        tabControllerManager.reload()
        settingsNavigationController?.reload()
        accountsAndAddressesNavigationController.reload()

        if let sideMenuViewController = slidingViewController.underLeftViewController as? SideMenuViewController {
            sideMenuViewController.reload()
        }

        NotificationCenter.default.post(name: Constants.NotificationKeys.reloadToDismissViews, object: nil)

        // Legacy code for generating new addresses
        NotificationCenter.default.post(name: Constants.NotificationKeys.newAddress, object: nil)
    }

    /// Method to "cleanup" state when the app is backgrounded.
    func cleanupOnAppBackgrounded() {
        tabControllerManager.hideSendAndReceiveKeyboards()
        tabControllerManager.transactionsBitcoinViewController?.loadedAllTransactions = false
        tabControllerManager.transactionsBitcoinViewController?.messageIdentifier = nil
        tabControllerManager.dashBoardClicked(nil)

        closeSideMenu()
    }

    /// Observes symbol changes so that view controllers can reflect the new symbol
    private func observeSymbolChanges() {
        BlockchainSettings.App.shared.onSymbolLocalChanged = { [unowned self] _ in
            self.tabControllerManager.reloadSymbols()
            self.accountsAndAddressesNavigationController.reload()
            self.sideMenuViewController.reload()
        }
    }

    func reloadAfterMultiAddressResponse() {
        if WalletManager.shared.wallet.didReceiveMessageForLastTransaction {
            WalletManager.shared.wallet.didReceiveMessageForLastTransaction = false
            if let transaction = WalletManager.shared.latestMultiAddressResponse?.transactions.firstObject as? Transaction {
                tabControllerManager.receiveBitcoinViewController?.paymentReceived(UInt64(abs(transaction.amount)), showBackupReminder: false)
            }
        }

        tabControllerManager.reloadAfterMultiAddressResponse()
        settingsNavigationController?.reloadAfterMultiAddressResponse()
        accountsAndAddressesNavigationController.reload()
        sideMenuViewController.reload()

        NotificationCenter.default.post(name: Constants.NotificationKeys.reloadToDismissViews, object: nil)
        NotificationCenter.default.post(name: Constants.NotificationKeys.newAddress, object: nil)
        NotificationCenter.default.post(name: Constants.NotificationKeys.multiAddressResponseReload, object: nil)
    }
}

extension AppCoordinator: SideMenuViewControllerDelegate {
    func sideMenuViewController(_ viewController: SideMenuViewController, didTapOn item: SideMenuItem) {
        AnalyticsService.shared.trackEvent(title: item.rawValue)
        switch item {
        case .upgrade:
            handleUpgrade()
        case .backup:
            handleBackup()
        case .accountsAndAddresses:
            handleAccountsAndAddresses()
        case .settings:
            handleSettings()
        case .webLogin:
            handleWebLogin()
        case .support:
            handleSupport()
        case .logout:
            handleLogout()
        case .buyBitcoin:
            handleBuyBitcoin()
        case .pit:
            handlePit()
        case .lockbox:
            let storyboard = UIStoryboard(name: "LockboxViewController", bundle: nil)
            let lockboxViewController = storyboard.instantiateViewController(withIdentifier: "LockboxViewController") as! LockboxViewController
            lockboxViewController.modalTransitionStyle = .coverVertical
            UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(lockboxViewController, animated: true)
        }
    }

    private func handleUpgrade() {
        AppCoordinator.shared.showHdUpgradeView()
    }

    private func handleBackup() {
        showBackupView()
    }

    private func handleAccountsAndAddresses() {
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(
            accountsAndAddressesNavigationController,
            animated: true
        ) { [weak self] in
            guard let strongSelf = self else { return }

            let wallet = strongSelf.walletManager.wallet

            guard !BlockchainSettings.App.shared.hideTransferAllFundsAlert &&
                strongSelf.accountsAndAddressesNavigationController.viewControllers.count == 1 &&
                wallet.didUpgradeToHd() &&
                wallet.getTotalBalanceForSpendableActiveLegacyAddresses() >= wallet.dust() &&
                strongSelf.accountsAndAddressesNavigationController.assetSelectorView.selectedAsset == .bitcoin else {
                    return
            }

            strongSelf.accountsAndAddressesNavigationController.alertUser(toTransferAllFunds: false)
        }
    }

    private func handleSettings() {
        showSettingsView()
    }
    
    private func handlePit() {
        PitCoordinator.shared.start(from: tabControllerManager)
    }

    private func handleWebLogin() {
        let webLoginViewController = WebLoginViewController()
        let navigationViewController = BCNavigationController(
            rootViewController: webLoginViewController,
            title: LocalizationConstants.SideMenu.loginToWebWallet
        )
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(
            navigationViewController,
            animated: true
        )
    }

    private func handleSupport() {
        let title = String(format: LocalizationConstants.openArg, Constants.Url.blockchainSupport)
        let alert = UIAlertController(
            title: title,
            message: LocalizationConstants.youWillBeLeavingTheApp,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: LocalizationConstants.continueString, style: .default) { _ in
                guard let url = URL(string: Constants.Url.blockchainSupport) else { return }
                UIApplication.shared.open(url)
            }
        )
        alert.addAction(
            UIAlertAction(title: LocalizationConstants.cancel, style: .cancel)
        )
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(
            alert,
            animated: true
        )
    }

    private func handleLogout() {
        let alert = UIAlertController(
            title: LocalizationConstants.SideMenu.logout,
            message: LocalizationConstants.SideMenu.logoutConfirm,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: LocalizationConstants.okString, style: .default) { _ in
                AuthenticationCoordinator.shared.logout(showPasswordView: true)
            }
        )
        alert.addAction(UIAlertAction(title: LocalizationConstants.cancel, style: .cancel))
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(
            alert,
            animated: true
        )
    }

    private func handleBuyBitcoin() {
        BuySellCoordinator.shared.showBuyBitcoinView()
    }
    
    private func handleExchange() {
        ExchangeCoordinator.shared.start(rootViewController: self.tabControllerManager)
    }
}

extension AppCoordinator: WalletAccountInfoAndExchangeRatesDelegate {
    func didGetAccountInfoAndExchangeRates() {
        loadingViewPresenter.hide()
        reloadAfterMultiAddressResponse()
    }
}

extension AppCoordinator: WalletBackupDelegate {
    func didBackupWallet() {
        walletManager.wallet.getHistoryForAllAssets()
    }

    func didFailBackupWallet() {
        walletManager.wallet.getHistoryForAllAssets()
    }
}

extension AppCoordinator: WalletHistoryDelegate {
    func didFailGetHistory(error: String?) {
        guard let errorMessage = error, errorMessage.count > 0 else {
            AlertViewPresenter.shared.standardError(message: LocalizationConstants.Errors.noInternetConnectionPleaseCheckNetwork)
            return
        }
        AnalyticsService.shared.trackEvent(title: "btc_history_error", parameters: ["error": errorMessage])
        AlertViewPresenter.shared.standardError(message: LocalizationConstants.Errors.balancesGeneric)
    }

    func didFetchEthHistory() {
        loadingViewPresenter.hide()
        reload()
    }

    func didFetchBitcoinCashHistory() {
        loadingViewPresenter.hide()
        reload()
    }
}

// MARK: - DevSupporting

extension AppCoordinator: DevSupporting {
    @objc func showDebugView(from presenter: DebugViewPresenter) {
        let debugViewController = DebugTableViewController()
        debugViewController.presenter = presenter
        let navigationController = UINavigationController(rootViewController: debugViewController)
        UIApplication.shared.keyWindow?.rootViewController?.topMostViewController?.present(navigationController, animated: true)
    }
}
