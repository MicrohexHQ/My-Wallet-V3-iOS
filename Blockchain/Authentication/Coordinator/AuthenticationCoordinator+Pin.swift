//
//  AuthenticationCoordinator+Pin.swift
//  Blockchain
//
//  Created by Chris Arriola on 4/30/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import PlatformKit

/// Used as a gateway to abstract any pin related login
extension AuthenticationCoordinator {

    /// Returns `true` in case the login pin screen is displayed
    @objc var isDisplayingLoginAuthenticationFlow: Bool {
        return pinRouter?.isDisplayingLoginAuthentication ?? false
    }
    
    /// Change existing pin code. Used from settings mostly.
    func changePin() {
        let logout = { [weak self] () -> Void in
            self?.logout(showPasswordView: true)
        }
        pinRouter = PinRouter(flow: .change(logoutRouting: logout))
        pinRouter.execute()
    }
    
    /// Create a new pin code. Used during onboarding, when the user is required to define a pin code before entering his wallet.
    func createPin() {
        pinRouter = PinRouter(flow: .create) { [weak self] _ in
            self?.alertPresenter.showMobileNoticeIfNeeded()
        }
        pinRouter.execute()
    }

    /// Authenticate using a pin code. Used during login when the app enters active state.
    func authenticatePin() {
        // If already authenticating, skip this as the screen is already presented
        guard pinRouter == nil || !pinRouter.isDisplayingLoginAuthentication else {
            return
        }
        let logout = { [weak self] () -> Void in
            self?.logout(showPasswordView: true)
        }
        pinRouter = PinRouter(flow: .authenticate(from: .background, logoutRouting: logout)) { [weak self] input in
            guard let pinDecryptionKey = input.pinDecryptionKey else { return }
            self?.postAuthentication(pinDecryptionKey)
        }
        pinRouter.execute()
    }
    
    /// Validates pin for any in-app flow, for example: enabling touch-id/face-id auth.
    func enableBiometrics() {
        let logout = { [weak self] () -> Void in
            self?.logout(showPasswordView: true)
        }
        pinRouter = PinRouter(flow: .enableBiometrics(logoutRouting: logout)) { [weak self] input in
            guard let pinDecryptionKey = input.pinDecryptionKey else { return }
            self?.postAuthentication(pinDecryptionKey)
        }
        pinRouter.execute()
    }
    
    // TODO: Dump this in favor of using one of the new gateways to PIN flow.
    /// Shows the pin entry view.
    func showPinEntryView() {
        if walletManager.didChangePassword {
            showPasswordModal()
        } else if appSettings.isPinSet {
            authenticatePin()
        } else {
            createPin()
        }
    }
    
    // Auth at login or when enabling biometric
    private func postAuthentication(_ decryptionKey: String) {
        
        // Otherwise, use the decryption key to authenticate the user and download their wallet
        let encryptedPinPassword = appSettings.encryptedPinPassword!
        guard let decryptedPassword = walletManager.wallet.decrypt(
            encryptedPinPassword,
            password: decryptionKey,
            pbkdf2_iterations: Int32(Constants.Security.pinPBKDF2Iterations)
            ), !decryptedPassword.isEmpty else {
                recorder.error(PinError.decryptedPasswordWithZeroLength)
                offerAuthenticatingAgain()
                return
        }
        
        guard let guid = appSettings.guid, let sharedKey = appSettings.sharedKey else {
            alertPresenter.showKeychainReadError()
            return
        }
        
        // Continue authentication
        let payload = PasscodePayload(guid: guid, password: decryptedPassword, sharedKey: sharedKey)
        authenticationManager.authenticate(using: payload, andReply: authHandler)
    }
    
    private func offerAuthenticatingAgain() {
        let actions = [
            UIAlertAction(title: LocalizationConstants.Authentication.enterPassword, style: .cancel) { [unowned self] _ in
                self.showPasswordModal()
            },
            UIAlertAction(title: LocalizationConstants.Authentication.retryValidation, style: .default) { [unowned self] _ in
                self.pinRouter.execute()
            }
        ]
        alertPresenter.standardNotify(
            message: LocalizationConstants.Pin.validationErrorMessage,
            title: LocalizationConstants.Pin.validationError,
            actions: actions
        )
    }
}
