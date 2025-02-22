//
//  BCCreateWalletView
//  Blockchain
//
//  Created by Ben Reeves on 18/03/2012.
//  Copyright (c) 2012 Blockchain Luxembourg S.A. All rights reserved.
//

#import "BCCreateWalletView.h"
#import "BuyBitcoinViewController.h"
#import "Blockchain-Swift.h"
#import "BCWebViewController.h"

@implementation BCCreateWalletView

+ (BCCreateWalletView *)instanceFromNib
{
    UINib *nib = [UINib nibWithNibName:@"MainWindow" bundle:[NSBundle mainBundle]];
    NSArray *objs = [nib instantiateWithOwner:nil options:nil];
    for (id object in objs) {
        if ([object isKindOfClass:[BCCreateWalletView class]]) {
            return (BCCreateWalletView *) object;
        }
    }
    return (BCCreateWalletView *) [objs objectAtIndex:0];
}

#pragma mark - Lifecycle

- (void)awakeFromNib
{
    [super awakeFromNib];

    UIButton *createButton = [UIButton buttonWithType:UIButtonTypeCustom];
    createButton.frame = CGRectMake(0, 0, self.window.frame.size.width, 46);
    createButton.backgroundColor = UIColor.brandSecondary;
    [createButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    createButton.titleLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_LARGE];
    self.createButton = createButton;

    emailTextField.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_SMALL];
    passwordTextField.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_SMALL];
    password2TextField.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_SMALL];

    emailTextField.inputAccessoryView = createButton;
    passwordTextField.inputAccessoryView = createButton;
    password2TextField.inputAccessoryView = createButton;
    
    passwordTextField.textColor = [UIColor grayColor];
    password2TextField.textColor = [UIColor grayColor];

    passwordFeedbackLabel.adjustsFontSizeToFitWidth = YES;

    UIFont *agreementLabelFont = [UIFont fontWithName:FONT_GILL_SANS_REGULAR size:FONT_SIZE_EXTRA_EXTRA_SMALL];
    agreementLabel.font = agreementLabelFont;
    
    self.agreementTappableLabel = [[UILabel alloc] initWithFrame:CGRectMake(agreementTappablePlaceholderLabel.frame.origin.x, agreementTappablePlaceholderLabel.frame.origin.y, self.bounds.size.width, agreementTappablePlaceholderLabel.frame.size.height)];
    self.agreementTappableLabel.userInteractionEnabled = YES;
    [self addSubview:self.agreementTappableLabel];
    
    self.agreementTappableLabel.font = agreementLabelFont;

    agreementLabel.text = [LocalizationConstantsObjcBridge createWalletLegalAgreementPrefix];

    NSString *termsOfService = [LocalizationConstantsObjcBridge termsOfService];
    NSString *privacyPolicy = [LocalizationConstantsObjcBridge privacyPolicy];
    self.agreementTappableLabel.text = [NSString stringWithFormat:@"%@ & %@", termsOfService, privacyPolicy];

    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:self.agreementTappableLabel.text attributes:@{NSFontAttributeName: agreementLabelFont, NSForegroundColorAttributeName: agreementLabel.textColor}];
    [attributedText addForegroundColor:[UIColor brandSecondary] to:termsOfService];
    [attributedText addForegroundColor:[UIColor brandSecondary] to:privacyPolicy];
    self.agreementTappableLabel.attributedText = attributedText;

    UILabel *measuringLabel = [[UILabel alloc] initWithFrame:self.agreementTappableLabel.bounds];
    measuringLabel.font = self.agreementTappableLabel.font;
    measuringLabel.text = self.agreementTappableLabel.text;

    UITapGestureRecognizer *tapGestureTermsOfService = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showTermsOfService)];
    UIView *tappableViewTermsOfService = [self viewWithTapGesture:tapGestureTermsOfService onSubstring:termsOfService ofText:self.agreementTappableLabel.text inLabel:measuringLabel];
    [tappableViewTermsOfService changeYPosition:tappableViewTermsOfService.frame.origin.y - 8];
    [self.agreementTappableLabel addSubview:tappableViewTermsOfService];

    UITapGestureRecognizer *tapGesturePrivacyPolicy = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showPrivacyPolicy)];
    UIView *tappableViewPrivacyPolicy = [self viewWithTapGesture:tapGesturePrivacyPolicy onSubstring:privacyPolicy ofText:self.agreementTappableLabel.text inLabel:measuringLabel];
    [tappableViewPrivacyPolicy changeYPosition:tappableViewPrivacyPolicy.frame.origin.y - 8];
    [self.agreementTappableLabel addSubview:tappableViewPrivacyPolicy];
    
    emailTextField.accessibilityIdentifier = AccessibilityIdentifiers_CreateWalletScreen.emailField;
    passwordTextField.accessibilityIdentifier = AccessibilityIdentifiers_CreateWalletScreen.passwordField;
    password2TextField.accessibilityIdentifier = AccessibilityIdentifiers_CreateWalletScreen.confirmPasswordField;
    tappableViewTermsOfService.accessibilityIdentifier = AccessibilityIdentifiers_CreateWalletScreen.termsOfServiceTappableView;
    tappableViewPrivacyPolicy.accessibilityIdentifier = AccessibilityIdentifiers_CreateWalletScreen.privacyPolicyTappableView;
    self.createButton.accessibilityIdentifier = AccessibilityIdentifiers_CreateWalletScreen.createWalletButton;
}

- (void)createBlankWallet
{
    [WalletManager.sharedInstance.wallet loadBlankWallet];
}

// Make sure keyboard comes back if use is returning from TOS
- (void)didMoveToWindow
{
    [emailTextField becomeFirstResponder];
}

- (void)setIsRecoveringWallet:(BOOL)isRecoveringWallet
{
    _isRecoveringWallet = isRecoveringWallet;
    
    if (_isRecoveringWallet) {
        [self.createButton removeTarget:self action:@selector(createAccountClicked:) forControlEvents:UIControlEventTouchUpInside];
        [self.createButton addTarget:self action:@selector(showRecoveryPhraseView:) forControlEvents:UIControlEventTouchUpInside];
        [self.createButton setTitle:BC_STRING_CONTINUE forState:UIControlStateNormal];
    } else {
        [self.createButton removeTarget:self action:@selector(showRecoveryPhraseView:) forControlEvents:UIControlEventTouchUpInside];
        [self.createButton addTarget:self action:@selector(createAccountClicked:) forControlEvents:UIControlEventTouchUpInside];
        [self.createButton setTitle:BC_STRING_CREATE_WALLET forState:UIControlStateNormal];
    }
}

#pragma mark - BCModalContentView Lifecyle methods

- (void)prepareForModalPresentation
{
    emailTextField.delegate = self;
    passwordTextField.delegate = self;
    password2TextField.delegate = self;
    
    [self clearSensitiveTextFields];

    // TICKET: IOS-1281 avoid interacting directly with user defaults
#ifdef DEBUG
    if (DebugSettings.sharedInstance.createWalletPrefill) {
        NSString *customEmail = DebugSettings.sharedInstance.createWalletEmailPrefill;
        NSInteger time = round([[NSDate date] timeIntervalSince1970]);
        NSString *suffix = [NSString stringWithFormat:@"+%ld", (long)time];
        if (DebugSettings.sharedInstance.createWalletEmailRandomSuffix) {
            NSArray *components = [customEmail componentsSeparatedByString:@"@"];
            emailTextField.text = [[[components firstObject] stringByAppendingString:suffix] stringByAppendingFormat:@"@%@", [components lastObject]];
        } else {
            emailTextField.text = customEmail;
        }

        passwordTextField.text = @"testpassword!";
        password2TextField.text = @"testpassword!";
        [self checkPasswordStrength];
    }
#endif
    
    _recoveryPhraseView.recoveryPassphraseTextField.delegate = self;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Scroll up to fit all entry fields on small screens
        if (!IS_568_SCREEN) {
            CGRect frame = self.frame;
            
            frame.origin.y = -SCROLL_HEIGHT_SMALL_SCREEN;
            
            self.frame = frame;
        }
        
        [self->emailTextField becomeFirstResponder];
    });
}

- (void)prepareForModalDismissal
{
    emailTextField.delegate = nil;
}

#pragma mark - Actions

- (IBAction)showRecoveryPhraseView:(id)sender
{
    if (![self isReadyToSubmitForm]) {
        return;
    };
    
    [self hideKeyboard];

    [[ModalPresenter sharedInstance] showModalWithContent:self.recoveryPhraseView closeType:ModalCloseTypeBack showHeader:true headerText:[LocalizationConstantsObjcBridge onboardingRecoverFunds] onDismiss:^{
        [self.createButton removeTarget:self action:@selector(recoverWalletClicked:) forControlEvents:UIControlEventTouchUpInside];
    } onResume:^{
        [self.recoveryPhraseView.recoveryPassphraseTextField performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.3f];
    }];
    
    [self.createButton removeTarget:self action:@selector(showRecoveryPhraseView:) forControlEvents:UIControlEventTouchUpInside];
    [self.createButton addTarget:self action:@selector(recoverWalletClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    self.recoveryPhraseView.recoveryPassphraseTextField.inputAccessoryView = self.createButton;
}

- (IBAction)recoverWalletClicked:(id)sender
{
    if (self.isRecoveringWallet) {
        NSString *recoveryPhrase = [[NSMutableString alloc] initWithString:self.recoveryPhraseView.recoveryPassphraseTextField.text];
        
        NSString *trimmedRecoveryPhrase = [recoveryPhrase stringByTrimmingCharactersInSet:
                                   [NSCharacterSet whitespaceCharacterSet]];
        
        [LoadingViewPresenter.sharedInstance showWith:BC_STRING_LOADING_RECOVERING_WALLET];
        [self.recoveryPhraseView.recoveryPassphraseTextField resignFirstResponder];

        [WalletManager.sharedInstance.wallet recoverWithEmail:emailTextField.text password:passwordTextField.text passphrase:trimmedRecoveryPhrase];
        
        WalletManager.sharedInstance.wallet.delegate = WalletManager.sharedInstance;
    }
}


// Get here from New Account and also when manually pairing
- (IBAction)createAccountClicked:(id)sender
{
    if (![self isReadyToSubmitForm]) {
        return;
    };
    
    [self hideKeyboard];
        
    // Get callback when wallet is done loading
    // Continue in walletJSReady callback
    WalletManager.sharedInstance.wallet.delegate = self;

    [[LoadingViewPresenter sharedInstance] showCircularWith:LocalizationConstantsObjcBridge.loadingWallet];
 
    // Load the JS without a wallet
    [WalletManager.sharedInstance.wallet performSelector:@selector(loadBlankWallet) withObject:nil afterDelay:DELAY_KEYBOARD_DISMISSAL];
}

- (void)showTermsOfService
{
    [self launchWebViewControllerWithTitle:[LocalizationConstantsObjcBridge termsOfService] URLString:[ConstantsObjcBridge termsOfServiceURLString]];
}

- (void)showPrivacyPolicy
{
    [self launchWebViewControllerWithTitle:[LocalizationConstantsObjcBridge privacyPolicy] URLString:[ConstantsObjcBridge privacyPolicyURLString]];
}

#pragma mark - Wallet Delegate method

- (void)walletJSReady
{
    // JS is loaded - now create the wallet
    [WalletManager.sharedInstance.wallet newAccount:self.tmpPassword email:emailTextField.text];
}

- (void)didCreateNewAccount:(NSString*)guid sharedKey:(NSString*)sharedKey password:(NSString*)password
{
    emailTextField.text = nil;
    passwordTextField.text = nil;
    password2TextField.text = nil;

    WalletManager.sharedInstance.wallet.delegate = WalletManager.sharedInstance;

    // Reset wallet
    [WalletManager.sharedInstance forgetWallet];
        
    // Load the newly created wallet
    [WalletManager.sharedInstance.wallet loadWalletWithGuid:guid sharedKey:sharedKey password:password];
    
    WalletManager.sharedInstance.wallet.isNew = YES;
    BuySellCoordinator.sharedInstance.buyBitcoinViewController.isNew = YES;

    BlockchainSettings.sharedOnboardingInstance.hasSeenAllCards = NO;
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:USER_DEFAULTS_KEY_LAST_CARD_OFFSET];

    BlockchainSettings.sharedAppInstance.hasSeenEmailReminder = NO;
    BlockchainSettings.sharedAppInstance.hasEndedFirstSession = NO;
    BlockchainSettings.sharedAppInstance.dateOfLastSecurityReminder = NULL;
    
    BlockchainSettings.sharedOnboardingInstance.shouldHideBuySellCard = YES;
}

- (void)errorCreatingNewAccount:(NSString*)message
{
    if ([message isEqualToString:@""]) {
        [AlertViewPresenter.sharedInstance showNoInternetConnectionAlert];
    } else if ([message isEqualToString:ERROR_TIMEOUT_REQUEST]){
        [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:LocalizationConstantsObjcBridge.timedOut title:BC_STRING_ERROR in:nil handler: nil];
    } else if ([message isEqualToString:ERROR_FAILED_NETWORK_REQUEST] || [message containsString:ERROR_TIMEOUT_ERROR] || [[message stringByReplacingOccurrencesOfString:@" " withString:@""] containsString:ERROR_STATUS_ZERO]){
        dispatch_after(DELAY_KEYBOARD_DISMISSAL, dispatch_get_main_queue(), ^{
            [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:[LocalizationConstantsObjcBridge requestFailedCheckConnection] title:BC_STRING_ERROR in:nil handler:nil];
        });
    } else {
        [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:message title:BC_STRING_ERROR in:nil handler:nil];
    }
}

#pragma mark - Textfield Delegates


- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == emailTextField) {
        [passwordTextField becomeFirstResponder];
    }
    else if (textField == passwordTextField) {
        [password2TextField becomeFirstResponder];
    }
    else if (textField == password2TextField) {
        if (self.isRecoveringWallet) {
            [self.createButton setTitle:[LocalizationConstantsObjcBridge onboardingRecoverFunds] forState:UIControlStateNormal];
            [self showRecoveryPhraseView:nil];
        } else {
            [self createAccountClicked:textField];
        }
    }
    else if (textField == self.recoveryPhraseView.recoveryPassphraseTextField) {
        [self recoverWalletClicked:textField];
    }
    
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == emailTextField) {
        if (!emailTextField.text.isEmail) {
            self.createButton.backgroundColor = UIColor.keyPadButton;
            self.createButton.userInteractionEnabled = NO;
        } else {
            self.createButton.backgroundColor = UIColor.brandSecondary;
            self.createButton.userInteractionEnabled = YES;
        }
    }
    if (textField == passwordTextField) {
        [self performSelector:@selector(checkPasswordStrength) withObject:nil afterDelay:0.01];
    }
    
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (passwordTextField.text.length == 0) {
        passwordFeedbackLabel.hidden = YES;
        passwordStrengthMeter.hidden = YES;
    }
}

#pragma mark - Helpers

- (UIView *)viewWithTapGesture:(UITapGestureRecognizer *)tapGesture onSubstring:(NSString *)substring ofText:(NSString *)text inLabel:(UILabel *)label
{
    CGRect tappableArea = [label boundingRectForCharacterRange:[text rangeOfString:substring]];
    UIView *tappableView = [[UIView alloc] initWithFrame:tappableArea];
    tappableView.userInteractionEnabled = YES;
    [tappableView addGestureRecognizer:tapGesture];
    return tappableView;
}

- (void)launchWebViewControllerWithTitle:(NSString *)title URLString:(NSString *)urlString
{
    BCWebViewController *webViewController = [[BCWebViewController alloc] initWithTitle:title];
    webViewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    [webViewController loadURL:urlString];
    [UIApplication.sharedApplication.keyWindow.rootViewController.topMostViewController presentViewController:webViewController animated:true completion:nil];
}

- (void)didRecoverWallet
{
    [self clearSensitiveTextFields];
    self.recoveryPhraseView.recoveryPassphraseTextField.hidden = NO;
}

- (void)showPassphraseTextField
{
    self.recoveryPhraseView.recoveryPassphraseTextField.hidden = NO;
}

- (void)hideKeyboard
{
    [emailTextField resignFirstResponder];
    [passwordTextField resignFirstResponder];
    [password2TextField resignFirstResponder];
    
    [self.recoveryPhraseView.recoveryPassphraseTextField resignFirstResponder];
}

- (void)clearSensitiveTextFields
{
    passwordTextField.text = nil;
    password2TextField.text = nil;
    passwordStrengthMeter.progress = 0;
    self.passwordStrength = 0;
    
    passwordTextField.layer.borderColor = UIColor.gray2.CGColor;
    passwordFeedbackLabel.textColor = [UIColor darkGrayColor];
    
    self.recoveryPhraseView.recoveryPassphraseTextField.text = @"";
}

- (void)checkPasswordStrength
{
    passwordFeedbackLabel.hidden = NO;
    passwordStrengthMeter.hidden = NO;
    
    NSString *password = passwordTextField.text;
    
    UIColor *color;
    NSString *description;
    
    float passwordStrength = [WalletManager.sharedInstance.wallet getStrengthForPassword:password];

    if (passwordStrength < 25) {
        color = UIColor.error;
        description = BC_STRING_PASSWORD_STRENGTH_WEAK;
    }
    else if (passwordStrength < 50) {
        color = UIColor.brandYellow;
        description = BC_STRING_PASSWORD_STRENGTH_REGULAR;
    }
    else if (passwordStrength < 75) {
        color = UIColor.brandSecondary;
        description = BC_STRING_PASSWORD_STRENGTH_NORMAL;
    }
    else {
        color = UIColor.green;
        description = BC_STRING_PASSWORD_STRENGTH_STRONG;
    }
    
    self.passwordStrength = passwordStrength;
    
    [UIView animateWithDuration:ANIMATION_DURATION animations:^{
        self->passwordFeedbackLabel.text = description;
        self->passwordFeedbackLabel.textColor = color;
        self->passwordStrengthMeter.progress = passwordStrength/100;
        self->passwordStrengthMeter.progressTintColor = color;
        self->passwordTextField.layer.borderColor = color.CGColor;
    }];
}

- (BOOL)isReadyToSubmitForm
{
    
    if (!emailTextField.text.isEmail) {
        [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:BC_STRING_PLEASE_PROVIDE_AN_EMAIL_ADDRESS title:BC_STRING_ERROR in:nil handler: nil];
        [emailTextField becomeFirstResponder];
        return NO;
    }

    self.tmpPassword = passwordTextField.text;
    
    if (!self.tmpPassword || [self.tmpPassword length] == 0) {
        [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:LocalizationConstantsObjcBridge.noPasswordEntered title:BC_STRING_ERROR in:nil handler:nil];
        [passwordTextField becomeFirstResponder];
        return NO;
    }
    
    if ([self.tmpPassword isEqualToString:emailTextField.text]) {
        [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:BC_STRING_PASSWORD_MUST_BE_DIFFERENT_FROM_YOUR_EMAIL title:BC_STRING_ERROR in:nil handler:nil];
        [passwordTextField becomeFirstResponder];
        return NO;
    }
    
    if (self.passwordStrength < 25) {
        [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:BC_STRING_PASSWORD_NOT_STRONG_ENOUGH title:BC_STRING_ERROR in:nil handler:nil];
        [passwordTextField becomeFirstResponder];
        return NO;
    }
    
    if ([self.tmpPassword length] > 255) {
        [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:BC_STRING_PASSWORD_MUST_BE_LESS_THAN_OR_EQUAL_TO_255_CHARACTERS title:BC_STRING_ERROR in:nil handler:nil];
        [passwordTextField becomeFirstResponder];
        return NO;
    }
    
    if (![self.tmpPassword isEqualToString:[password2TextField text]]) {
        [[AlertViewPresenter sharedInstance] standardNotifyWithMessage:BC_STRING_PASSWORDS_DO_NOT_MATCH title:BC_STRING_ERROR in:nil handler:nil];
        [password2TextField becomeFirstResponder];
        return NO;
    }
    
    if (!Reachability.hasInternetConnection) {
        [AlertViewPresenter.sharedInstance showNoInternetConnectionAlert];
        return NO;
    }
    
    return YES;
}

@end
