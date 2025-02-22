//
//  BlockchainSettings.swift
//  Blockchain
//
//  Created by Chris Arriola on 4/17/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import PlatformKit

/**
 Settings for the current user.
 All settings are written and read from NSUserDefaults.
*/
@objc
final class BlockchainSettings: NSObject {

    // class function declared so that the BlockchainSettings singleton can be accessed from obj-C
    // TODO remove this once all Obj-C references of this file have been removed
    @objc class func sharedAppInstance() -> App {
        return App.shared
    }

    @objc class func sharedOnboardingInstance() -> Onboarding {
        return Onboarding.shared
    }

    // MARK: - App

    @objc
    class App: NSObject, AppSettingsAuthenticating, SwipeToReceiveConfiguring {
        static let shared = App()

        private lazy var defaults: UserDefaults = {
            return UserDefaults.standard
        }()

        // class function declared so that the App singleton can be accessed from obj-C
        @objc class func sharedInstance() -> App {
            return App.shared
        }

        // MARK: - Properties

        /**
         Determines if the application should *ask the system* to show the app review prompt.

         - Note:
         This value increments whenever the application is launched or enters the foreground.

         - Important:
         This setting **should** be set reset upon logging the user out of the application.
         */
        @objc var appBecameActiveCount: Int {
            get {
                return defaults.integer(forKey: UserDefaults.Keys.appBecameActiveCount.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.appBecameActiveCount.rawValue)
            }
        }
        
        @objc var didRequestCameraPermissions: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.didRequestCameraPermissions.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.didRequestCameraPermissions.rawValue)
            }
        }
        
        @objc var didRequestNotificationPermissions: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.didRequestNotificationPermissions.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.didRequestNotificationPermissions.rawValue)
            }
        }

        /**
         Stores the encrypted wallet password.

         - Note:
         The value of this setting is the result of calling the `encrypt(_ data: String, password: String)` function of the wallet.

         - Important:
         The encryption key is generated from the pin created by the user.
         legacyEncryptedPinPassword is required for wallets that created a PIN prior to Homebrew release - see IOS-1537
        */
        var encryptedPinPassword: String? {
            get {
                return defaults.string(forKey: UserDefaults.Keys.encryptedPinPassword.rawValue) ??
                    defaults.string(forKey: UserDefaults.Keys.legacyEncryptedPinPassword.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.encryptedPinPassword.rawValue)
                defaults.set(nil, forKey: UserDefaults.Keys.legacyEncryptedPinPassword.rawValue)
            }
        }

        @objc var enableCertificatePinning: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.DebugKeys.enableCertificatePinning.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.DebugKeys.enableCertificatePinning.rawValue)
            }
        }

        @objc var hasEndedFirstSession: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.hasEndedFirstSession.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.hasEndedFirstSession.rawValue)
            }
        }

        @objc var hasSeenEmailReminder: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.hasSeenEmailReminder.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.hasSeenEmailReminder.rawValue)
            }
        }

        @objc var pin: String? {
            get {
                return KeychainItemWrapper.pinFromKeychain()
            }
            set {
                guard let pin = newValue else {
                    KeychainItemWrapper.removePinFromKeychain()
                    return
                }
                KeychainItemWrapper.setPINInKeychain(pin)
            }
        }

        @objc var isPinSet: Bool {
            return pinKey != nil && encryptedPinPassword != nil
        }

        @objc var pinKey: String? {
            get {
                return defaults.string(forKey: UserDefaults.Keys.pinKey.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.pinKey.rawValue)
            }
        }

        var onSymbolLocalChanged: ((Bool) -> Void)?

        /// Property indicating whether or not the currency symbol that should be used throughout the app
        /// should be fiat, if set to true, or the asset-specific symbol, if false.
        @objc var symbolLocal: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.symbolLocal.rawValue)
            }
            set {
                let oldValue = symbolLocal

                defaults.set(newValue, forKey: UserDefaults.Keys.symbolLocal.rawValue)

                if oldValue != newValue {
                    onSymbolLocalChanged?(newValue)
                }
            }
        }

        @objc var fiatCurrencySymbol: String {
            let defaultValue = "$"
            guard let addressResponse = WalletManager.shared.latestMultiAddressResponse else { return defaultValue }
            guard let symbol = addressResponse.symbol_local else { return defaultValue }
            guard let value = symbol.symbol else { return defaultValue }
            return value
        }

        @objc var fiatCurrencyCode: String {
            let defaultValue = "USD"
            guard let addressResponse = WalletManager.shared.latestMultiAddressResponse else { return defaultValue }
            guard let symbol = addressResponse.symbol_local else { return defaultValue }
            guard let code = symbol.code else { return defaultValue }
            return code
        }

        @objc func fiatSymbolFromCode(currencyCode: String) -> String? {
            guard let currencyCodeDict = WalletManager.shared.wallet.btcRates[currencyCode] as? [String: Any] else {
                return nil
            }
            return currencyCodeDict["symbol"] as? String
        }

        /// The first 5 characters of SHA256 hash of the user's password
        @objc var passwordPartHash: String? {
            get {
                return defaults.string(forKey: UserDefaults.Keys.passwordPartHash.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.passwordPartHash.rawValue)
            }
        }

        /**
         Keeps track if the user has elected to use biometric authentication in the application.

         - Note:
         This setting should be **deprecated** in the future, as we should always assume a user
         wants to use this feature if it is enabled system-wide.

         - SeeAlso:
         [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/ios/user-interaction/authentication)
         */
        @objc var biometryEnabled: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.biometryEnabled.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.biometryEnabled.rawValue)
            }
        }

        @objc var guid: String? {
            get {
                return KeychainItemWrapper.guid()
            }
            set {
                guard let guid = newValue else {
                    KeychainItemWrapper.removeGuidFromKeychain()
                    return
                }
                KeychainItemWrapper.setGuidInKeychain(guid)
            }
        }

        /**
         Keeps track of the last time the security reminder alert was shown to the user.

         - Note:
         The value of this setting is updated each time the `showSecurityReminder` method of the `ReminderPresenter` is called.

         The value of this setting is set to `nil` upon calling the `didCreateNewAccount` method of the wallet delegate.

         The default value of this setting is `nil`.
        */
        @objc var dateOfLastSecurityReminder: NSDate? {
            get {
                return defaults.object(forKey: UserDefaults.Keys.reminderModalDate.rawValue) as? NSDate
            }
            set {
                guard let date = newValue else {
                    defaults.removeObject(forKey: UserDefaults.Keys.reminderModalDate.rawValue)
                    return
                }
                defaults.set(date, forKey: UserDefaults.Keys.reminderModalDate.rawValue)
            }
        }

        @objc var sharedKey: String? {
            get {
                return KeychainItemWrapper.sharedKey()
            }

            set {
                guard let sharedKey = newValue else {
                    KeychainItemWrapper.removeSharedKeyFromKeychain()
                    return
                }
                KeychainItemWrapper.setSharedKeyInKeychain(sharedKey)
            }
        }

        /**
         Determines if the application should allow access to swipe-to-receive on the pin screen.

         - Note:
         The value of this setting is controlled by a switch on the settings screen.

         The default of this setting is `true`.
         */
        @objc var swipeToReceiveEnabled: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.swipeToReceiveEnabled.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.swipeToReceiveEnabled.rawValue)
            }
        }

        @objc var hideTransferAllFundsAlert: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.hideTransferAllFundsAlert.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.hideTransferAllFundsAlert.rawValue)
            }
        }

        /// Ether address to be used for swipe to receive
        @objc var swipeAddressForEther: String? {
            get {
                return KeychainItemWrapper.getSingleSwipeAddress(for: .ether)
            }
            set {
                guard let etherAddress = newValue else {
                    KeychainItemWrapper.removeAllSwipeAddresses(for: .ether)
                    return
                }
                KeychainItemWrapper.setSingleSwipeAddress(etherAddress, for: .ether)
            }
        }

        /// XLM address to be used for swipe to receive
        @objc var swipeAddressForStellar: String? {
            get {
                return KeychainItemWrapper.getSingleSwipeAddress(for: .stellar)
            }
            set {
                guard let xlmAddress = newValue else {
                    KeychainItemWrapper.removeAllSwipeAddresses(for: .stellar)
                    return
                }
                KeychainItemWrapper.setSingleSwipeAddress(xlmAddress, for: .stellar)
            }
        }
        
        /// XLM address to be used for swipe to receive
        @objc var swipeAddressForPax: String? {
            get {
                return KeychainItemWrapper.getSingleSwipeAddress(for: .pax)
            }
            set {
                guard let paxAddress = newValue else {
                    KeychainItemWrapper.removeAllSwipeAddresses(for: .pax)
                    return
                }
                KeychainItemWrapper.setSingleSwipeAddress(paxAddress, for: .pax)
            }
        }

        /**
         Determines the number of labeled addresses for the default account.

         - Note:
         This value is set when the wallet has gotten its latest multi-address response.

         This setting is currently only used in the `didGet(_ response: MultiAddressResponse)` function of the wallet manager.
        */
        @objc var defaultAccountLabelledAddressesCount: Int {
            get {
                return defaults.integer(forKey: UserDefaults.Keys.defaultAccountLabelledAddressesCount.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.defaultAccountLabelledAddressesCount.rawValue)
            }
        }

        /**
         Determines if the application should never prompt the user to write an app review.

         - Note:
         This value is set to `true` if the user has chosen to write an app review or not to be asked again.
        */
        var dontAskUserToShowAppReviewPrompt: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.dontAskUserToShowAppReviewPrompt.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.dontAskUserToShowAppReviewPrompt.rawValue)
            }
        }

        /**
         Determines if the user deep linked into the app using the airdrop dynamic link. This value is used in various
         places to handle the airdrop flow (e.g. prompt the user to KYC to finish the airdrop, to continue KYC'ing if
         they have already gone through the KYC flow, etc.)

         - Important:
         This setting **MUST** be set to `false` upon logging the user out of the application.
         */
        @objc var didTapOnAirdropDeepLink: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.didTapOnAirdropDeepLink.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.didTapOnAirdropDeepLink.rawValue)
            }
        }
        
        /**
         Determines if the user has dismissed the `Swap` card. Users that have not completed
         a swap transaction will see this card until they submit a transaction or they dismiss the card.
         
         - Important:
         This setting **MUST** be set to `false` upon logging the user out of the application.
         */
        @objc var shouldHideSwapCard: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.shouldHideSwapCard.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.shouldHideSwapCard.rawValue)
            }
        }
        
        /**
         Determines if the user has dismissed the `PIT Linking` card. Users that have not linked
        their wallet to the PIT will see this card until they either link their wallet or dismiss
         the card.
         
         - Important:
         This setting **MUST** be set to `false` upon logging the user out of the application.
         */
        @objc var shouldHidePITLinkingCard: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.shouldHidePITLinkingCard.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.shouldHidePITLinkingCard.rawValue)
            }
        }

        /// Determines if the app already tried to route the user for the airdrop flow as a result
        /// of tapping on a deep link
        var didAttemptToRouteForAirdrop: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.didAttemptToRouteForAirdrop.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.didAttemptToRouteForAirdrop.rawValue)
            }
        }

        /// Determines if the user deep linked into the app using a document resubmission link. This
        /// value is used to continue KYC'ing at the Verify Your Identity step.
        var didTapOnDocumentResubmissionDeepLink: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.didTapOnDocumentResubmissionDeepLink.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.didTapOnDocumentResubmissionDeepLink.rawValue)
            }
        }

        /// Determines if the user deep linked into the app using an email verification link. This
        /// value is used to continue KYC'ing at the Verify Email step.
        var didTapOnKycDeepLink: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.didTapOnKycDeepLink.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.didTapOnKycDeepLink.rawValue)
            }
        }

        /// Property saved from parsing '' query param from document resubmission deeplink.
        /// Used to pass reasons for initial verification failure to display in the Verify Your
        /// Identity screen
        var documentResubmissionLinkReason: String? {
            get {
                return defaults.string(forKey: UserDefaults.Keys.documentResubmissionLinkReason.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.documentResubmissionLinkReason.rawValue)
            }
        }
        
        /// Determines whether we show a modal prompt telling users that they are about to
        /// have a Coinify account created on their behalf and buy continuing to Buy-Sell
        /// they agree to Coinify's TOS
        var didAcceptCoinifyTOS: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.didAcceptCoinifyTOS.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.didAcceptCoinifyTOS.rawValue)
            }
        }
        
        /// Users that are linking their PIT account to their blockchain wallet will deep-link
        /// from the PIT into the mobile app.
        var pitLinkIdentifier: String? {
            get {
                return defaults.string(forKey: UserDefaults.Keys.pitLinkIdentifier.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.pitLinkIdentifier.rawValue)
            }
        }
        
        var didTapOnPitDeepLink: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.didTapOnPitDeepLink.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.didTapOnPitDeepLink.rawValue)
            }
        }

        override init() {
            // Private initializer so that `shared` and `sharedInstance` are the only ways to
            // access an instance of this class.
            super.init()

            defaults.register(defaults: [
                UserDefaults.Keys.swipeToReceiveEnabled.rawValue: true,
                UserDefaults.Keys.assetType.rawValue: AssetType.bitcoin.rawValue,
                UserDefaults.DebugKeys.enableCertificatePinning.rawValue: true
            ])
            migratePasswordAndPinIfNeeded()
            handleMigrationIfNeeded()
        }

        // MARK: - Public

        /**
         Resets app-specific settings back to their initial value.
         - Note:
           This function will not reset any settings which are derived from wallet options.
        */
        func reset() {
            // TICKET: IOS-1365 - Finish UserDefaults refactor (tickets, documentation, linter issues)
            // TODO: - reset all appropriate settings upon logging out
            clearPin()
            appBecameActiveCount = 0
            didTapOnAirdropDeepLink = false
            didTapOnPitDeepLink = false
            didAttemptToRouteForAirdrop = false
            didTapOnKycDeepLink = false
            didAcceptCoinifyTOS = false
            shouldHidePITLinkingCard = false
            pitLinkIdentifier = nil

            KYCSettings.shared.reset()

            Logger.shared.info("Application settings have been reset.")
        }

        /// - Warning: Calling This function will remove **ALL** settings in the application.
        func clear() {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            Logger.shared.info("Application settings have been cleared.")
        }

        func clearPin() {
            pin = nil
            encryptedPinPassword = nil
            pinKey = nil
            passwordPartHash = nil
        }

        /// Migrates pin and password from NSUserDefaults to the Keychain
        func migratePasswordAndPinIfNeeded() {
            guard let password = defaults.string(forKey: UserDefaults.Keys.password.rawValue),
                let pinStr = defaults.string(forKey: UserDefaults.Keys.pin.rawValue),
                let pinUInt = UInt(pinStr) else {
                    return
            }

            WalletManager.shared.wallet.password = password

            Pin(code: pinUInt).save(using: self)

            defaults.removeObject(forKey: UserDefaults.Keys.password.rawValue)
            defaults.removeObject(forKey: UserDefaults.Keys.pin.rawValue)
        }

        //: Handles settings migration when keys change
        func handleMigrationIfNeeded() {
            defaults.migrateLegacyKeysIfNeeded()
        }
    }

    // MARK: - App

    /// Encapsulates all onboarding-related settings for the user
    @objc class Onboarding: NSObject {
        static let shared: Onboarding = Onboarding()

        private lazy var defaults: UserDefaults = {
            return .standard
        }()

        /// Property indicating if setting up biometric authentication failed
        var didFailBiometrySetup: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.didFailBiometrySetup.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.didFailBiometrySetup.rawValue)
            }
        }

        /// Property indicating if the user saw the HD wallet upgrade screen
        var hasSeenUpgradeToHdScreen: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.hasSeenUpgradeToHdScreen.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.hasSeenUpgradeToHdScreen.rawValue)
            }
        }

        /**
         Determines if the biometric authentication setup should be shown to the user.

         - Note:
         This value is set to `true` if the value of `didFailBiometrySetup` is `true` and the value of `biometryEnabled` is false.

         This value is set to `false` whenever the user is reminded to very their email.

         The default value of this setting is `false`.
        */
        var shouldShowBiometrySetup: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.shouldShowBiometrySetup.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.shouldShowBiometrySetup.rawValue)
            }
        }

        /**
         Determines if this is the first time the user is running the application.

         - Note:
         This value is set to `true` if the application is running for the first time.

         This setting is currently not used for anything else.
        */
        var firstRun: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.firstRun.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.firstRun.rawValue)
            }
        }

        /// Property indicating if the buy/sell onboarding card should be shown
        @objc var shouldHideBuySellCard: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.shouldHideBuySellCard.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.shouldHideBuySellCard.rawValue)
            }
        }

        /// Property indicating if the user has seen all onboarding cards
        @objc var hasSeenAllCards: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.hasSeenAllCards.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.hasSeenAllCards.rawValue)
            }
        }

        /// Property indicating whether or not the user has already seen, and clicked, on the
        /// Stellar "join the waitlist" onboarding card for receiving an XLM airdrop
        @objc var hasSeenAirdropJoinWaitlistCard: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.hasSeenAirdropJoinWaitlistCard.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.hasSeenAirdropJoinWaitlistCard.rawValue)
            }
        }

        /// Property indicating whether or not the user has already seen, and clicked, on the
        /// Stellar "Get Free XLM" bottom modal
        @objc var hasSeenGetFreeXlmModal: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.hasSeenGetFreeXlmModal.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.hasSeenGetFreeXlmModal.rawValue)
            }
        }
        
        @objc var hasSeenStellarAirdropRegistrationAlert: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.hasSeenStellarAirdropRegistrationAlert.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.hasSeenStellarAirdropRegistrationAlert.rawValue)
            }
        }
        
        @objc var hasDismissedCompleteYourProfileCard: Bool {
            get {
                return defaults.bool(forKey: UserDefaults.Keys.hasDismissedCompleteYourProfileCard.rawValue)
            }
            set {
                defaults.set(newValue, forKey: UserDefaults.Keys.hasDismissedCompleteYourProfileCard.rawValue)
            }
        }

        private override init() {
            super.init()
        }

        func reset() {
            hasSeenStellarAirdropRegistrationAlert = false
            hasDismissedCompleteYourProfileCard = false
            hasSeenGetFreeXlmModal = false
            hasSeenAirdropJoinWaitlistCard = false
        }
    }

    private override init() {
        // Private initializer so that an instance of BLockchainSettings can't be created
        super.init()
    }
}
