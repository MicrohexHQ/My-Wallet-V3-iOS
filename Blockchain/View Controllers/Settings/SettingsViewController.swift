//
//  SettingsTableViewCell.swift
//  Blockchain
//
//  Created by Justin on 7/3/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import UIKit
import LocalAuthentication
import CoreFoundation
import RxSwift
import PlatformKit
import PlatformUIKit

// TODO: Refactor this screen to VIPER
// - Cells are held strongly without using tableview queue mechanism.
// - Constant number of cells instead of dynamic.
// - Everything is hardcoded in storyboard
@IBDesignable @objc class SettingsTableViewController: UITableViewController,
AppSettingsController, UITextFieldDelegate, EmailDelegate, WalletAccountInfoDelegate {
    
    /// TODO: Dynamically aggregate visual info about sections and cells.
    struct Sections {
        let profile = 0
        let preferences = 1
        let pit = 2
        let security = 3
        let about = 4
        
        let includesPitLinking: Bool
        
        init(pitConfig: AppFeatureConfiguration = AppFeatureConfigurator.shared.configuration(for: .pitLinking)) {
            includesPitLinking = pitConfig.isEnabled
        }
    }
    
    // Row References
    
    //Profile
    let identityVerification = 0
    let profileWalletIdentifier = 1
    let profileEmail = 2
    let profileMobileNumber = 3
    let profileWebLogin = 4
    
    //Preferenes
    let preferencesEmailNotifications = 0
    let preferencesLocalCurrency = 1
    let securityTwoStep = 0
    let securityPasswordChange = 1
    let securityWalletRecoveryPhrase = 2
    let PINChangePIN = 3
    let aboutUs = 0
    let aboutTermsOfService = 1
    let aboutPrivacyPolicy = 2
    let aboutCookiePolicy = 3
    let pinBiometry = 4
    let pinSwipeToReceive = 5
    let pitIndex = 0
    
    let sections = Sections()
    
    var settingsController: SettingsTableViewController?
    var availableCurrenciesDictionary: [AnyHashable: Any] = [:]
    var allCurrencySymbolsDictionary: [AnyHashable: Any] = [:]
    private var enteredEmailString = ""
    private var emailString = ""
    private var mobileNumberString = ""
    private var changeFeeTextField: UITextField?
    private var currentFeePerKb: Float = 0.0
    private var isVerifyingMobileNumber = false
    private var isEnablingTwoStepSMS = false
    private var backupController: BackupNavigationViewController?
    weak var alertTargetViewController: UIViewController?
    weak var delegate: (UIViewController & EmailDelegate)!
    weak var numberDelegate: (UIViewController & MobileNumberDelegate)!
    let walletManager: WalletManager
    let authenticationService: NabuAuthenticationService
    
    lazy var repositoryAPI: PITAccountRepository = {
        return PITAccountRepository()
    }()
    
    let bag: DisposeBag = DisposeBag()
    var tiers: KYCUserTiersResponse?
    var didFetchTiers = false
    
    @IBOutlet var touchIDAsPin: SettingsToggleTableViewCell!
    @IBOutlet var swipeToReceive: SettingsToggleTableViewCell!
    
    private let loadingViewPresenter: LoadingViewPresenting = LoadingViewPresenter.shared
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    required init?(coder aDecoder: NSCoder) {
        self.walletManager = WalletManager.shared
        self.authenticationService = NabuAuthenticationService.shared
        super.init(coder: aDecoder)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
        self.walletManager.accountInfoDelegate = self
    }

    func verifyEmailTapped() {
        emailClicked()
    }

    func changeTwoStepTapped() {
        alertUserToChangeTwoStepVerification()
    }

    func mobileNumberClicked() {
        if walletManager.wallet.getTwoStepType() == AuthenticationTwoFactorType.sms.rawValue {
            let alertToDisableTwoFactorSMS = UIAlertController(title:
                String(format: "2-step Verification is currently enabled for %@.", "SMS"), message:
                String(format: "You must disable SMS 2-Step Verification before changing your mobile number (%@).",
                       mobileNumberString), preferredStyle: .alert)
            alertToDisableTwoFactorSMS.addAction(UIAlertAction(title: LocalizationConstants.okString, style: .cancel, handler: nil))
            if alertTargetViewController != nil {
                alertTargetViewController?.present(alertToDisableTwoFactorSMS, animated: true)
            } else {
                present(alertToDisableTwoFactorSMS, animated: true)
            }
            return
        }
        let verifyMobileNumberController = BCVerifyMobileNumberViewController(mobileDelegate: numberDelegate)
        navigationController?.pushViewController(verifyMobileNumberController!, animated: true)
    }
    func aboutUsClicked() {
        AboutUsViewController.present(in: self)
    }
    func termsOfServiceClicked() {
        let aboutViewController = SettingsWebViewController()
        aboutViewController.urlTargetString = Constants.Url.termsOfService
        let navigationController = BCNavigationController(rootViewController: aboutViewController, title: LocalizationConstants.tos)
        present(navigationController, animated: true)
    }
    func showPrivacyPolicy() {
        let aboutViewController = SettingsWebViewController()
        aboutViewController.urlTargetString = Constants.Url.privacyPolicy
        let navigationController = BCNavigationController(rootViewController: aboutViewController, title: LocalizationConstants.privacyPolicy)
        present(navigationController, animated: true)
    }
    func showCookiePolicy() {
        let aboutViewController = SettingsWebViewController()
        aboutViewController.urlTargetString = Constants.Url.privacyPolicy
        let navigationController = BCNavigationController(rootViewController: aboutViewController,
                                                          title: LocalizationConstantsObjcBridge.cookiePolicy())
        present(navigationController, animated: true)
    }
    
    func swapTapped() {
        KYCTiersViewController.routeToTiers(
            fromViewController: self
        ).disposed(by: bag)
    }
    
    func convertFloat(toString floatNumber: Float, forDisplay isForDisplay: Bool) -> String? {
        let feePerKbFormatter = NumberFormatter()
        feePerKbFormatter.numberStyle = .decimal
        feePerKbFormatter.maximumFractionDigits = 8
        let amountNumber = floatNumber
        let displayString = feePerKbFormatter.string(from: amountNumber as NSNumber)
        if isForDisplay {
            return displayString
        } else {
            let decimalSeparator =  Locale.current.decimalSeparator
            let keyboardSet = "1234567890"
            let numbersWithDecimalSeparatorString = "\(keyboardSet)\(decimalSeparator ?? "")"
            let characterSetFromString = CharacterSet(charactersIn: displayString ?? "")
            let numbersAndDecimalCharacterSet = CharacterSet(charactersIn: numbersWithDecimalSeparatorString)
            if !numbersAndDecimalCharacterSet.isSuperset(of: characterSetFromString) {
                // Current keypad will not support this character set; return string with known decimal separators "," and "."
                feePerKbFormatter.locale = NSLocale(localeIdentifier: "en_US") as Locale
                if decimalSeparator == "." {
                    return feePerKbFormatter.string(from: amountNumber as NSNumber)
                } else {
                    feePerKbFormatter.decimalSeparator = decimalSeparator ?? ""
                    return feePerKbFormatter.string(from: amountNumber as NSNumber)
                }
            }
            return displayString
        }
    }
    // MARK: - Web login
    func webLoginClicked() {
        let webLoginViewController = WebLoginViewController()
        navigationController?.pushViewController(webLoginViewController, animated: true)
    }
    // MARK: - Change Swipe to Receive
    @objc func switchSwipeToReceiveTapped(_ sender: UISwitch) {
        let swipeToReceiveEnabled = BlockchainSettings.sharedAppInstance().swipeToReceiveEnabled
        if !swipeToReceiveEnabled {
            let swipeToReceiveAlert = UIAlertController(title: LocalizationConstants.swipeReceive,
                                                        message: LocalizationConstants.Pin.revealAddress, preferredStyle: .alert)
            swipeToReceiveAlert.addAction(UIAlertAction(title: LocalizationConstants.enable, style: .default, handler: { _ in
                BlockchainSettings.sharedAppInstance().swipeToReceiveEnabled = !swipeToReceiveEnabled
                // Clear all swipe addresses in case default account has changed
                if !swipeToReceiveEnabled {
                    AssetAddressRepository.sharedInstance().removeAllSwipeAddresses()
                }
            }))
            swipeToReceiveAlert.addAction(UIAlertAction(title: LocalizationConstants.cancel, style: .cancel, handler: { _ in
                sender.isOn = false
            }))
            present(swipeToReceiveAlert, animated: true)
        } else {
            BlockchainSettings.sharedAppInstance().swipeToReceiveEnabled = !swipeToReceiveEnabled
            // Clear all swipe addresses in case default account has changed
            if !swipeToReceiveEnabled {
                AssetAddressRepository.sharedInstance().removeAllSwipeAddresses()
            }
        }
    }
    // MARK: - Biometrics
    /**
     Gets the biometric type description depending on whether the device supports Face ID or Touch ID.
     This method may also be used to quickly determine whether or not the user is enrolled in biometric authentication.
     @return The biometric type description of the authentication method.
     */
    func biometryTypeDescription() -> String? {
        let context = LAContext()
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            if #available(iOS 11.0, *) {
                if context.biometryType == .faceID {
                    return LocalizationConstants.faceId
                }
            } else {
                return LocalizationConstants.touchId
                // Fallback on earlier versions
            }
            return LocalizationConstants.touchId
        }
        return nil
    }
    @objc func biometrySwitchTapped(_ sender: UISwitch) {
        AuthenticationManager.sharedInstance().canAuthenticateUsingBiometry(andReply: { success, errorMessage in
            if success {
                self.toggleBiometry(sender)
            } else {
                BlockchainSettings.sharedAppInstance().biometryEnabled = false
                let alertBiometryError = UIAlertController(title: LocalizationConstants.Errors.error, message: errorMessage, preferredStyle: .alert)
                alertBiometryError.addAction(UIAlertAction(title: LocalizationConstants.okString, style: .cancel, handler: { _ in
                    sender.isOn = false
                }))
                self.present(alertBiometryError, animated: true)
            }
        })
    }
    
    func toggleBiometry(_ sender: UISwitch) {
        let biometryEnabled = BlockchainSettings.sharedAppInstance().biometryEnabled
        if !biometryEnabled {
            let biometryWarning = String(format: LocalizationConstantsObjcBridge.biometryWarning(), biometryTypeDescription()!)
            let alertForTogglingBiometry = UIAlertController(title: biometryTypeDescription(), message: biometryWarning, preferredStyle: .alert)
            alertForTogglingBiometry.addAction(UIAlertAction(title: LocalizationConstants.cancel, style: .cancel, handler: { _ in
                sender.isOn = false
            }))
            alertForTogglingBiometry.addAction(UIAlertAction(title: LocalizationConstants.continueString, style: .default, handler: { _ in
                AuthenticationCoordinator.shared.enableBiometrics()
            }))
            present(alertForTogglingBiometry, animated: true)
        } else {
            BlockchainSettings.sharedAppInstance().pin = nil
            BlockchainSettings.sharedAppInstance().biometryEnabled = false
        }
    }
    
    // MARK: - Change notifications
    func emailNotificationsEnabled() -> Bool {
        return walletManager.wallet.emailNotificationsEnabled()
    }
    @objc func toggleEmailNotifications(_ sender: UISwitch) {
        let indexPath = IndexPath(row: preferencesEmailNotifications, section: sections.preferences)
        if Reachability.hasInternetConnection() {
            if emailNotificationsEnabled() {
                walletManager.wallet.disableEmailNotifications()
            } else {
                if walletManager.wallet.getEmailVerifiedStatus() == true {
                    walletManager.wallet.enableEmailNotifications()
                } else {
                    alertUserOfError(LocalizationConstants.Authentication.verifyEmail)
                    sender.isOn = false
                    return
                }
            }
            let changeEmailNotificationsCell: UITableViewCell? = tableView.cellForRow(at: indexPath)
            changeEmailNotificationsCell?.isUserInteractionEnabled = false
            addObserversForChangingNotifications()
        } else {
            AlertViewPresenter.sharedInstance().showNoInternetConnectionAlert()
        }
    }

    func addObserversForChangingNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.changeNotificationsSuccess),
                                               name: NSNotification.Name(rawValue: "ChangeEmailNotifications"),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.changeNotificationsError),
                                               name: NSNotification.Name(rawValue: "ChangeEmailNotificationsError"), object: nil)
    }

    func removeObserversForChangingNotifications() {
        NotificationCenter.default.removeObserver(self,
                                                  name: NSNotification.Name(rawValue: "ChangeEmailNotifications"), object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: NSNotification.Name(rawValue: "ChangeEmailNotificationsError"), object: nil)
    }
    @objc func changeNotificationsSuccess() {
        removeObserversForChangingNotifications()
        loadingViewPresenter.show(with: LocalizationConstantsObjcBridge.syncingWallet())
        let changeEmailNotificationsCell: UITableViewCell? = tableView.cellForRow(at: IndexPath(
            row: preferencesEmailNotifications,
            section: sections.preferences))
        changeEmailNotificationsCell?.isUserInteractionEnabled = true
    }
    @objc func changeNotificationsError() {
        removeObserversForChangingNotifications()
        let indexPath = IndexPath(row: preferencesEmailNotifications, section: sections.preferences)
        let changeEmailNotificationsCell: UITableViewCell? = tableView.cellForRow(at: indexPath)
        changeEmailNotificationsCell?.isUserInteractionEnabled = true
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    // MARK: - Change Two Step
    @objc func showTwoStep() {
        performSingleSegue(withIdentifier: "twoStep", sender: nil)
    }
    func alertUserToChangeTwoStepVerification() {
        var alertTitle: String
        var isTwoStepEnabled = true
        let twoStepType = walletManager.wallet.getTwoStepType()
        if twoStepType == AuthenticationTwoFactorType.sms.rawValue {
            alertTitle = String(format: "2-step Verification is currently enabled for %@.", "SMS")
        } else if twoStepType ==  AuthenticationTwoFactorType.google.rawValue {
            alertTitle = String(format: "2-step Verification is currently enabled for %@.", "Google Authenticator")
        } else if twoStepType ==  AuthenticationTwoFactorType.yubiKey.rawValue {
            alertTitle = String(format: "2-step Verification is currently enabled for %@.", "Yubi Key")
        } else if twoStepType ==  AuthenticationTwoFactorType.none.rawValue {
            alertTitle = "2-step Verification is currently disabled."
            isTwoStepEnabled = false
        } else {
            alertTitle = "2-step Verification is cuerrently enabled for %@."
        }
        let alertForChangingTwoStep = UIAlertController(title: alertTitle, message:
        LocalizationConstants.Authentication.enableTwoStep,
                                                        preferredStyle: .alert)
        alertForChangingTwoStep.addAction(UIAlertAction(title: LocalizationConstants.cancel, style: .cancel, handler: nil))
        alertForChangingTwoStep.addAction(UIAlertAction(title:
            isTwoStepEnabled ? LocalizationConstants.disable : LocalizationConstants.enable,
                                                        style: .default, handler: { _ in
            self.changeTwoStepVerification()
        }))
        if alertTargetViewController != nil {
            alertTargetViewController?.present(alertForChangingTwoStep, animated: true)
        } else {
            present(alertForChangingTwoStep, animated: true)
        }
    }
    func changeTwoStepVerification() {
        if !Reachability.hasInternetConnection() {
            AlertViewPresenter.sharedInstance().showNoInternetConnectionAlert()
            return
        }
        if walletManager.wallet.getTwoStepType() == AuthenticationTwoFactorType.none.rawValue {
            isEnablingTwoStepSMS = true
            if walletManager.wallet.getSMSVerifiedStatus() == true {
                enableTwoStepForSMS()
            } else {
                mobileNumberClicked()
            }
        } else {
            disableTwoStep()
        }
    }
    func enableTwoStepForSMS() {
        prepareForForChangingTwoStep()
        walletManager.wallet.enableTwoStepVerificationForSMS()
    }
    func disableTwoStep() {
        prepareForForChangingTwoStep()
        walletManager.wallet.disableTwoStepVerification()
    }
    @objc func changeTwoStepSuccess() {
        if isEnablingTwoStepSMS {
            alertUserOfSuccess(LocalizationConstants.Authentication.twoStepSMS)
        } else {
            alertUserOfSuccess(LocalizationConstants.Authentication.twoStepOff)
        }
        isEnablingTwoStepSMS = false
        doneChangingTwoStep()
    }
    @objc func changeTwoStepError() {
        isEnablingTwoStepSMS = false
        alertUserOfError(LocalizationConstants.Errors.twoStep)
        doneChangingTwoStep()
        getAccountInfo()
    }
    // MARK: - Change Email
    func hasAddedEmail() -> Bool {
        if walletManager.wallet.getEmail() != nil {
            return true
        }
        return false
    }
    func getUserEmail() -> String? {
        return walletManager.wallet.getEmail()
    }
    func alertUser(toChangeEmail hasAddedEmail: Bool) {
        let alertViewTitle = hasAddedEmail ? LocalizationConstants.changeEmail : LocalizationConstants.addEmail
        let alertForChangingEmail = UIAlertController(title: alertViewTitle, message: LocalizationConstants.Errors.noEmail, preferredStyle: .alert)
        alertForChangingEmail.addAction(UIAlertAction(title: LocalizationConstants.cancel, style: .cancel, handler: { _ in
            // If the user cancels right after adding a legitimate email address, update accountInfo
            let emailCell: UITableViewCell? = self.tableView.cellForRow(at: IndexPath(row: self.profileEmail, section: self.sections.profile))
            if ((emailCell?.detailTextLabel?.text == LocalizationConstants.unverified) &&
                (alertForChangingEmail.title == LocalizationConstants.changeEmail)) ||
                !(self.getUserEmail() == self.emailString) {
                self.getAccountInfo()
            }
        }))
        alertForChangingEmail.addAction(UIAlertAction(title: LocalizationConstants.verify, style: .default, handler: { _ in
            let newEmail = alertForChangingEmail.textFields?.first?.text
            if (newEmail?.lowercased().replacingOccurrences(of: " ", with: "") ==
                self.getUserEmail()?.lowercased().replacingOccurrences(of: " ", with: "")) {
                self.alertUserOfError(LocalizationConstants.Errors.differentEmail)
                return
            }
            if self.walletManager.wallet.emailNotificationsEnabled() {
                self.alertUserAboutDisablingEmailNotifications(newEmail)
            } else {
                self.changeEmail(newEmail)
            }
        }))
        alertForChangingEmail.addTextField(configurationHandler: { textField in
            let secureTextField = textField as? BCSecureTextField
            secureTextField?.autocapitalizationType = .none
            secureTextField?.spellCheckingType = .no
            secureTextField?.returnKeyType = .done
            secureTextField?.text = hasAddedEmail ? self.getUserEmail() : ""
        })
        if alertTargetViewController != nil {
            alertTargetViewController?.present(alertForChangingEmail, animated: true)
        } else {
            present(alertForChangingEmail, animated: true)
        }
    }
    func alertUserAboutDisablingEmailNotifications(_ newEmail: String?) {
        enteredEmailString = newEmail!
        let alertForChangingEmail = UIAlertController(
            title: LocalizationConstants.newEmail,
            message: LocalizationConstants.Settings.notificationsDisabled,
            preferredStyle: .alert)
        alertForChangingEmail.addAction(UIAlertAction(title: LocalizationConstants.cancel, style: .cancel, handler: nil))
        alertForChangingEmail.addAction(UIAlertAction(title: LocalizationConstants.continueString, style: .default, handler: { _ in
            self.disableNotificationsThenChangeEmail(newEmail)
        }))
        if alertTargetViewController != nil {
            alertTargetViewController?.present(alertForChangingEmail, animated: true)
        } else {
            present(alertForChangingEmail, animated: true)
        }
    }
    func disableNotificationsThenChangeEmail(_ newEmail: String?) {
        loadingViewPresenter.show(with: LocalizationConstantsObjcBridge.syncingWallet())
        walletManager.wallet.disableEmailNotifications()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.changeEmailAfterDisablingNotifications),
                                               name: NSNotification.Name(rawValue: ConstantsObjcBridge.notificationKeyBackupSuccess()), object: nil)
    }
    @objc func changeEmailAfterDisablingNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: ConstantsObjcBridge.notificationKeyBackupSuccess()),
                                                  object: nil)
        changeEmail(enteredEmailString)
    }
    func alertUserToVerifyEmail() {
        let alertForVerifyingEmail = UIAlertController(title: String(
            format: "Verification email has been sent to %@.", emailString),
                                                       message: LocalizationConstants.Authentication.checkLink,
                                                       preferredStyle: .alert)
        alertForVerifyingEmail.addAction(UIAlertAction(title:
            LocalizationConstants.Authentication.resendVerificationEmail,
                                                       style: .default, handler: { _ in
            self.resendVerificationEmail()
        }))
        alertForVerifyingEmail.addAction(UIAlertAction(title: LocalizationConstants.openMailApp, style: .default, handler: { _ in
            UIApplication.shared.openMailApplication()
        }))
        alertForVerifyingEmail.addAction(UIAlertAction(title: LocalizationConstants.okString, style: .cancel, handler: { _ in
            self.getAccountInfo()
        }))
        if alertTargetViewController != nil {
            alertTargetViewController?.present(alertForVerifyingEmail, animated: true)
        } else {
            navigationController?.present(alertForVerifyingEmail, animated: true)
        }
    }
    func resendVerificationEmail() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.resendVerificationEmailSuccess),
                                               name: NSNotification.Name(rawValue: "ResendVerificationEmail"), object: nil)
        walletManager.wallet.resendVerificationEmail(emailString)
    }
    @objc func resendVerificationEmailSuccess() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "ResendVerificationEmail"), object: nil)
        alertUserToVerifyEmail()
    }
    @objc func changeEmailSuccess() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "ChangeEmail"), object: nil)
        emailString = enteredEmailString
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(500), execute: {
            self.alertUserToVerifyEmail()
        })
    }
    // MARK: - Wallet Recovery Phrase
    @objc func showBackup() {
        if !(backupController != nil) {
            let storyboard = UIStoryboard(name: "Backup", bundle: nil)
            backupController = (storyboard.instantiateViewController(withIdentifier: "BackupNavigation") as! BackupNavigationViewController)
        }
        backupController?.wallet = walletManager.wallet
        backupController?.modalTransitionStyle = .coverVertical
        present(backupController!, animated: true)
    }
    func changePassword() {
        performSingleSegue(withIdentifier: "changePassword", sender: nil)
    }
    // MARK: - TextField Delegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        weak var weakSelf: SettingsTableViewController? = self
        if alertTargetViewController != nil {
            alertTargetViewController?.dismiss(animated: true) {
                if textField.tag == 7 {
                    weakSelf?.verifyMobileNumber(textField.text)
                } else if textField.tag == 6 {
                    weakSelf?.verifyMobileNumberViewController(nil, changeMobileNumber: textField.text)
                }
            }
            return true
        }
        dismiss(animated: true) {
            if textField.tag == 7 {
                weakSelf?.verifyMobileNumber(textField.text)
            } else if textField.tag == 6 {
                weakSelf?.verifyMobileNumberViewController(nil, changeMobileNumber: textField.text)
            }
        }
        return true
    }
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField == changeFeeTextField {
            let newString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
            let points = newString?.components(separatedBy: ".")
            let commas = newString?.components(separatedBy: Locale.current.decimalSeparator ?? "")
            // Only one comma or point in input field allowed
            if (points?.count ?? 0) > 2 || (commas?.count ?? 0) > 2 {
                return false
            }
            // Only 1 leading zero
            if points?.count == 1 || commas?.count == 1 {
                if Int(range.location) == 1 && !(string == ".") && !(string == Locale.current.decimalSeparator) && (textField.text == "0") {
                    return false
                }
            }
            let decimalSeparator = Locale.current.decimalSeparator
            let numbersWithDecimals = "1234567890"
            let toSeperate = decimalSeparator ?? ""
            let numbersWithDecimalSeparatorString = "\(numbersWithDecimals)\(toSeperate)"
            let characterSetFromString = CharacterSet(charactersIn: newString ?? "")
            let numbersAndDecimalCharacterSet = CharacterSet(charactersIn: numbersWithDecimalSeparatorString)
            // Only accept numbers and decimal representations
            if !numbersAndDecimalCharacterSet.isSuperset(of: characterSetFromString) {
                return false
            }
        }
        return true
    }
    // MARK: - Segue
    func performSingleSegue(withIdentifier identifier: String?, sender: Any?) {
        if navigationController?.topViewController == self {
            performSegue(withIdentifier: identifier ?? "", sender: sender)
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "currency" {
            let settingsSelectorTableViewController = segue.destination as? SettingsSelectorTableViewController
            settingsSelectorTableViewController?.itemsDictionary = availableCurrenciesDictionary
        } else if segue.identifier == "twoStep" {
            if let twoStepViewController = segue.destination as? SettingsTwoStepViewController {
                twoStepViewController.settingsController = self
                alertTargetViewController = twoStepViewController
            }
        }
    }

    @objc func didGetAccountInfo() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "GetAccountInfo"), object: nil)
        let accountInfoUpdate: (() -> ()) = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.updateAccountInfo()
        }
        syncNabuWithWallet(successHandler: accountInfoUpdate, errorHandler: { _ in
            accountInfoUpdate()
        })
        .disposed(by: bag)
        
    }

    func getAccountInfo() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.didGetAccountInfo),
                                               name: NSNotification.Name(rawValue: "GetAccountInfo"), object: nil)
        walletManager.wallet.getAccountInfo()
    }
    func updateCurrencySymbols() {
        allCurrencySymbolsDictionary = walletManager.wallet.btcRates
        reloadTableView()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isEnablingTwoStepSMS = false
        let navigationController = self.navigationController as? SettingsNavigationController
        navigationController?.headerLabel.text = LocalizationConstants.settings
        let loadedSettings: Bool = (UserDefaults.standard.object(forKey: "loadedSettings") != nil)
        if !loadedSettings {
            reload()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        switch (indexPath.section, indexPath.row) {
        case (sections.security, pinBiometry):
            if !(biometryTypeDescription() != nil) {
                touchIDAsPin.isHidden = true
                return 0
            } else {
                touchIDAsPin.isHidden = false
                return 56
            }
        case (sections.security, pinSwipeToReceive):
            if !AppFeatureConfigurator.sharedInstance().configuration(for: .swipeToReceive).isEnabled {
                swipeToReceive?.isHidden = true
                return 0
            } else {
                swipeToReceive?.isHidden = false
                return 56
            }
        case (sections.pit, _):
            return sections.includesPitLinking ? 56 : 0
        default:
            break
        }
        return 56
    }

    @objc func reload() {
        backupController?.reload()
        getAccountInfo()
        getAllCurrencySymbols()
    }
    @objc func reloadAfterMultiAddressResponse() {
        backupController?.reload()
        updateAccountInfo()
        updateCurrencySymbols()
    }
    func updateAccountInfo(completion: (() -> ())? = nil) {
        DispatchQueue.main.async {
            UserDefaults.standard.set(1, forKey: "loadedSettings")
            if self.walletManager.wallet.getFiatCurrencies() != nil {
                self.availableCurrenciesDictionary = self.walletManager.wallet.getFiatCurrencies()
            }
            self.updateEmailAndMobileStrings()
            if type(of: self.alertTargetViewController) == SettingsTwoStepViewController.self {
                let twoStepViewController = self.alertTargetViewController as? SettingsTwoStepViewController
                twoStepViewController?.updateUI()
            }
            completion?()
        }
    }
    func updateEmailAndMobileStrings() {
        let emailString = walletManager.wallet.getEmail()
        if emailString != nil {
            self.emailString = emailString!
        }
        let mobileNumberString = walletManager.wallet.getSMSNumber()
        if mobileNumberString != nil {
            self.mobileNumberString = mobileNumberString!
        }
    }
    func changeEmail(_ emailString: String?) {
        NotificationCenter.default.addObserver(self,
                                               selector:
            #selector(self.changeEmailSuccess), name: NSNotification.Name(rawValue: "ChangeEmail"),
                                                object: nil)
        enteredEmailString = emailString!
        walletManager.wallet.changeEmail(emailString)
    }
}

extension SettingsTableViewController: MobileNumberDelegate {

    func verifyMobileNumberViewController(_ viewController: BCVerifyMobileNumberViewController?, changeMobileNumber numberString: String?) {
        guard let number = numberString else { return }

        walletManager.wallet.changeMobileNumber(number, success: { [weak self] in
            viewController?.reload()
            self?.mobileNumberString = number
            self?.getAccountInfo()
            self?.verifyMobileNumberViewControllerAlertUser(toVerifyMobileNumber: viewController)
        }, error: { [weak self] in
            viewController?.reload()
            self?.isEnablingTwoStepSMS = false
            self?.alertUserOfError("Invalid mobile number.")
        })
    }

    func isMobileVerified() -> Bool {
        return walletManager.wallet.hasVerifiedMobileNumber()
    }

    func getMobileNumber() -> String? {
        return walletManager.wallet.getSMSNumber()
    }

    func verifyMobileNumberViewControllerShowVerifyAlertIfNeeded(_ viewController: BCVerifyMobileNumberViewController?) -> Bool {
        let shouldShowVerifyAlert = isVerifyingMobileNumber
        if shouldShowVerifyAlert {
            verifyMobileNumberViewControllerAlertUser(toVerifyMobileNumber: viewController)
            isVerifyingMobileNumber = false
        }
        return shouldShowVerifyAlert
    }

    func verifyMobileNumberViewControllerAlertUser(toVerifyMobileNumber viewController: BCVerifyMobileNumberViewController?) {
        isVerifyingMobileNumber = true
        let alertForVerifyingMobileNumber = UIAlertController(
            title: LocalizationConstants.Authentication.enterVerification,
            message: String(format: "Sent to %@", mobileNumberString),
            preferredStyle: .alert)
        alertForVerifyingMobileNumber.addAction(
            UIAlertAction(title: LocalizationConstants.Authentication.resendVerification, style: .default, handler: { _ in
                self.verifyMobileNumberViewController(viewController, changeMobileNumber: self.mobileNumberString)
            })
        )
        alertForVerifyingMobileNumber.addAction(UIAlertAction(title: LocalizationConstants.verify, style: .default, handler: { _ in
            self.verifyMobileNumber(alertForVerifyingMobileNumber.textFields?.first?.text, viewController: viewController)
        }))
        alertForVerifyingMobileNumber.addAction(UIAlertAction(title: LocalizationConstants.cancel, style: .cancel, handler: { _ in
            // If the user cancels right after adding a legitimate number, update accountInfo
            self.isEnablingTwoStepSMS = false
            self.getAccountInfo()
        }))
        alertForVerifyingMobileNumber.addTextField(configurationHandler: { textField in
            let secureTextField = textField as? BCSecureTextField
            secureTextField?.autocapitalizationType = .none
            secureTextField?.autocorrectionType = .no
            secureTextField?.spellCheckingType = .no
            secureTextField?.tag = 7
            secureTextField?.delegate = self
            secureTextField?.returnKeyType = .done
            secureTextField?.placeholder = LocalizationConstants.enterCode
        })
        if alertTargetViewController != nil {
            alertTargetViewController?.present(alertForVerifyingMobileNumber, animated: true)
        } else {
            navigationController?.present(alertForVerifyingMobileNumber, animated: true)
        }
    }

    private func verifyMobileNumber(_ code: String?, viewController: BCVerifyMobileNumberViewController? = nil) {
        walletManager.wallet.verifyMobileNumber(code, success: { [weak self] in
            viewController?.reload()
            self?.isVerifyingMobileNumber = false
            if let isEnablingTwoStepSMS = self?.isEnablingTwoStepSMS, isEnablingTwoStepSMS {
                self?.enableTwoStepForSMS()
                return
            }
            self?.alertUserOfSuccess(LocalizationConstants.Authentication.hasVerified)
        }, error: { [weak self] in
            viewController?.reload()
            self?.isEnablingTwoStepSMS = false
            if let settingsNavController = self?.navigationController as? SettingsNavigationController {
                settingsNavController.onDismissViewController = {
                    self?.verifyMobileNumberViewControllerAlertUser(toVerifyMobileNumber: viewController)
                }
            }
        })
    }
}
