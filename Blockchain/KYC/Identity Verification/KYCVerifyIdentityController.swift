//
//  KYCVerifyIdentityController.swift
//  Blockchain
//
//  Created by Maurice A. on 7/17/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import PlatformUIKit
import SafariServices
import Veriff

/// Account verification screen in KYC flow
final class KYCVerifyIdentityController: KYCBaseViewController {
    
    enum VerificationProviders {
        case veriff
    }

    // MARK: Factory

    override class func make(with coordinator: KYCCoordinator) -> KYCVerifyIdentityController {
        let controller = makeFromStoryboard()
        controller.coordinator = coordinator
        controller.pageType = .verifyIdentity
        return controller
    }

    // MARK: - Views

    @IBOutlet private var nextButton: PrimaryButtonContainer!

    // MARK: - UILabels
    
    @IBOutlet private var headline: UILabel!
    @IBOutlet private var subheadline: UILabel!
    @IBOutlet private var passport: UILabel!
    @IBOutlet private var nationalIDCard: UILabel!
    @IBOutlet private var residenceCard: UILabel!
    @IBOutlet private var driversLicense: UILabel!
    @IBOutlet private var enableCamera: UILabel!
    @IBOutlet private var enableCameraDescription: UILabel!
    @IBOutlet private var countrySupportedHeader: UILabel!
    @IBOutlet private var countrySupportedDescription: ActionableLabel!

    // MARK: UIStackView
    
    @IBOutlet private var documentTypeStackView: UIStackView!

    // MARK: - Public Properties

    weak var delegate: KYCVerifyIdentityDelegate?

    // MARK: - Private Properties

    private let veriffVersion: String = "/v1/"

    private let currentProvider = VerificationProviders.veriff

    private var countryCode: String?

    private var presenter: KYCVerifyIdentityPresenter!
    private let loadingViewPresenter: LoadingViewPresenting = LoadingViewPresenter.shared
    
    private var countrySupportedTrigger: ActionableTrigger!

    // MARK: - KYCCoordinatorDelegate

    override func apply(model: KYCPageModel) {
        guard case let .verifyIdentity(countryCode) = model else { return }
        self.countryCode = countryCode
    }

    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        addAccessibilityIds()
        dependenciesSetup()
        nextButton.actionBlock = { [unowned self] in
            switch self.currentProvider {
            case .veriff:
                self.presenter.didTapNext()
            }
        }
        enableCamera.text = LocalizationConstants.KYC.enableCamera
        enableCameraDescription.text = LocalizationConstants.KYC.enableCameraDescription
        passport.text = LocalizationConstants.KYC.passport
        nationalIDCard.text = LocalizationConstants.KYC.nationalIdentityCard
        residenceCard.text = LocalizationConstants.KYC.residencePermit
        driversLicense.text = LocalizationConstants.KYC.driversLicense
        setupCountrySupportedText()
    }

    private func setupCountrySupportedText() {
        countrySupportedHeader.text = LocalizationConstants.KYC.isCountrySupportedHeader

        countrySupportedDescription.delegate = self

        countrySupportedTrigger = ActionableTrigger(
            text: LocalizationConstants.KYC.isCountrySupportedDescription1,
            CTA: LocalizationConstants.KYC.isCountrySupportedDescription2,
            secondary: LocalizationConstants.KYC.isCountrySupportedDescription3
        ) { [unowned self] in
            guard let url = URL(string: "https://support.blockchain.com/hc/en-us/articles/360018751932") else {
                return
            }
            let viewController = SFSafariViewController(url: url)
            self.present(viewController, animated: true)
        }

        let description = NSMutableAttributedString(
            string: countrySupportedTrigger.primaryString,
            attributes: defaultAttributes()
        )
        description.append(
            NSAttributedString(
                string: " " + countrySupportedTrigger.callToAction,
                attributes: actionAttributes()
            )
        )
        if let secondaryString = countrySupportedTrigger.secondaryString {
            description.append(
                NSAttributedString(
                    string: " " + secondaryString,
                    attributes: defaultAttributes()
                )
            )
        }
        countrySupportedDescription.attributedText = description
    }

    private func addAccessibilityIds() {
        headline.accessibilityIdentifier = AccessibilityIdentifiers.KYCVerifyIdentityScreen.headerText
        subheadline.accessibilityIdentifier = AccessibilityIdentifiers.KYCVerifyIdentityScreen.subheaderText
        passport.accessibilityIdentifier = AccessibilityIdentifiers.KYCVerifyIdentityScreen.passportText
        nationalIDCard.accessibilityIdentifier = AccessibilityIdentifiers.KYCVerifyIdentityScreen.nationalIDCardText
        residenceCard.accessibilityIdentifier = AccessibilityIdentifiers.KYCVerifyIdentityScreen.residenceCardText
        driversLicense.accessibilityIdentifier = AccessibilityIdentifiers.KYCVerifyIdentityScreen.driversLicenseText
        enableCamera.accessibilityIdentifier = AccessibilityIdentifiers.KYCVerifyIdentityScreen.enableCameraHeaderText
        enableCameraDescription.accessibilityIdentifier = AccessibilityIdentifiers.KYCVerifyIdentityScreen.enableCameraSubheaderText
        countrySupportedHeader.accessibilityIdentifier = AccessibilityIdentifiers.KYCVerifyIdentityScreen.countrySupportedHeaderText
        countrySupportedDescription.accessibilityIdentifier = AccessibilityIdentifiers.KYCVerifyIdentityScreen.countrySupportedSubheaderText
    }

    private func actionAttributes() -> [NSAttributedString.Key: Any] {
        return [.font: Font(.branded(.montserratRegular), size: .custom(18.0)).result,
                .foregroundColor: UIColor.brandSecondary]
    }

    private func defaultAttributes() -> [NSAttributedString.Key: Any] {
        return [.font: Font(.branded(.montserratRegular), size: .custom(18.0)).result,
                .foregroundColor: countrySupportedDescription.textColor]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let code = countryCode else { return }
        presenter.presentDocumentTypeOptions(code)
    }

    private func dependenciesSetup() {
        let interactor = KYCVerifyIdentityInteractor()
        let identityPresenter = KYCVerifyIdentityPresenter(interactor: interactor, loadingView: self)
        identityPresenter.identityView = self
        identityPresenter.delegate = self
        presenter = identityPresenter
        delegate = presenter
    }

    /// Begins identity verification and presents the view
    ///
    /// - Parameters:
    ///   - document: enum of identity types mapped to an identity provider
    ///   - provider: the current provider of verification services
    fileprivate func startVerificationFlow(_ document: KYCDocumentType? = nil, provider: VerificationProviders = .veriff) {
        switch provider {
        case .veriff:
            veriffCredentialsRequest()
        }
    }

    private func didSelect(_ document: KYCDocumentType) {
        startVerificationFlow(document, provider: currentProvider)
    }
}

extension KYCVerifyIdentityController: ActionableLabelDelegate {
    func targetRange(_ label: ActionableLabel) -> NSRange? {
        return countrySupportedTrigger.actionRange()
    }

    func actionRequestingExecution(label: ActionableLabel) {
        countrySupportedTrigger.execute()
    }
}

extension KYCVerifyIdentityController: KYCVerifyIdentityView {
    func showDocumentTypes(_ types: [KYCDocumentType]) {
        documentTypeStackView.isHidden = false
        types.forEach { [weak self] type in
            guard let this = self else { return }
            switch type {
            case .driversLicense:
                this.driversLicense.isHidden = false
            case .nationalIdentityCard:
                this.nationalIDCard.isHidden = false
            case .passport:
                this.passport.isHidden = false
            case .residencePermit:
                this.residenceCard.isHidden = false
            }
        }
    }
}

extension KYCVerifyIdentityController: LoadingView {
    func showLoadingIndicator() {
        nextButton.isLoading = true
    }

    func hideLoadingIndicator() {
        nextButton.isLoading = false
    }

    func showErrorMessage(_ message: String) {
        AlertViewPresenter.shared.standardError(message: message)
    }
}

extension KYCVerifyIdentityController: VeriffController {
    func onVeriffSubmissionCompleted() {
        loadingViewPresenter.show(with: LocalizationConstants.KYC.submittingInformation)
        delegate?.submitVerification(onCompleted: { [unowned self] in
            self.dismiss(animated: true, completion: {
                self.coordinator.handle(event: .nextPageFromPageType(self.pageType, nil))
            })},
        onError: { error in
            self.dismiss(animated: true, completion: {
                AlertViewPresenter.shared.standardError(message: LocalizationConstants.Errors.genericError)
            })
            Logger.shared.error("Failed to submit verification \(error.localizedDescription)")
        })
    }

    func onVeriffError(message: String) {
        showErrorMessage(message)
    }

    func onVeriffCancelled() {
        loadingViewPresenter.hide()
        dismiss(animated: true, completion: { [weak self] in
            guard let this = self else { return }
            this.coordinator.handle(event: .nextPageFromPageType(this.pageType, nil))
        })
    }

    func veriffCredentialsRequest() {
        delegate?.createCredentials(onSuccess: { [weak self] credentials in
            guard let this = self else { return }
            this.launchVeriffController(credentials: credentials, version: this.veriffVersion)
        }, onError: { error in
            Logger.shared.error("Failed to get Veriff credentials. Error: \(error.localizedDescription)")
        })
    }
}

extension KYCVerifyIdentityController: CameraPromptingDelegate {
    func proceed() {
        startVerificationFlow()
    }
}
