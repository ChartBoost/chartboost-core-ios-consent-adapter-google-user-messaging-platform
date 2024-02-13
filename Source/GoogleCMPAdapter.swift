// Copyright 2023-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostCoreSDK
import UserMessagingPlatform

/// Chartboost Core Consent Usercentrics adapter.
@objc(CBCGoogleCMPAdapter)
@objcMembers
public final class GoogleCMPAdapter: NSObject, InitializableModule, ConsentAdapter {

    // MARK: - Properties

    /// The module identifier.
    public let moduleID = "google-cmp"

    /// The version of the module.
    public let moduleVersion = "0.2.1.0.0"

    /// The delegate to be notified whenever any change happens in the CMP consent status.
    /// This delegate is set by Core SDK and is an essential communication channel between Core and the CMP.
    /// Adapters should not set it themselves.
    public weak var delegate: ConsentAdapterDelegate?

    /// Google User Messaging Platform debug settings to pass when the requesting consent info updates.
    /// Make sure to update this property before initialization for it to take effect.
    public static var debugSettings: UMPDebugSettings?

    /// Indicates whether the CMP has determined that consent should be collected from the user.
    public var shouldCollectConsent: Bool {
        UMPConsentInformation.sharedInstance.formStatus == .available
        // TODO: also unknown? what happens after reset()? does it turn into unknown until consent info is updated again? what would we expect to happen?
    }

    /// The current consent status determined by the CMP.
    public var consentStatus: ConsentStatus {
        switch UMPConsentInformation.sharedInstance.consentStatus {
        case .unknown:
            return .unknown
        case .required:
            return .denied
        case .notRequired, .obtained:
            return .granted
        @unknown default:
            return .unknown
        }
    }

    /// Individualized consent status per partner SDK.
    ///
    /// The keys for advertising SDKs should match Chartboost Mediation partner adapter ids.
    public var partnerConsentStatus: [String: ConsentStatus] {
        [:] // Google User Messaging Platform does not provide consent status per partner
    }

    /// Detailed consent status for each consent standard, as determined by the CMP.
    ///
    /// Predefined consent standard constants, such as ``ConsentStandard/usp`` and ``ConsentStandard/tcf``, are provided
    /// by Core. Adapters should use them when reporting the status of a common standard.
    /// Custom standards should only be used by adapters when a corresponding constant is not provided by the Core.
    ///
    /// While Core also provides consent value constants, these are only applicable for the ``ConsentStandard/ccpa`` and
    /// ``ConsentStandard/gdpr`` standards. For other standards a custom value should be provided (e.g. a IAB TCF string
    /// for ``ConsentStandard/tcf``).
    public var consents: [ConsentStandard : ConsentValue] {
        var consents: [ConsentStandard: ConsentValue] = [:]
        consents[.gpp] = UserDefaults.standard.string(forKey: "IABGPP_HDR_GppString").map(ConsentValue.init(stringLiteral:))
        consents[.tcf] = UserDefaults.standard.string(forKey: "IABTCF_TCString").map(ConsentValue.init(stringLiteral:))
        consents[.usp] = UserDefaults.standard.string(forKey: "IABUSPrivacy_String").map(ConsentValue.init(stringLiteral:))
        return consents
    }

    // MARK: - Instantiation and Initialization

    /// The designated initializer for the module.
    /// The Chartboost Core SDK will invoke this initializer when instantiating modules defined on
    /// the dashboard through reflection.
    /// - parameter credentials: A dictionary containing all the information required to initialize
    /// this module, as defined on the Chartboost Core's dashboard.
    ///
    /// - note: Modules should not perform costly operations on this initializer.
    /// Chartboost Core SDK may instantiate and discard several instances of the same module.
    /// Chartboost Core SDK keeps strong references to modules that are successfully initialized.
    public init(credentials: [String : Any]?) {
        super.init()
        
        // Populate debug settings with backend info if available, and only it hasn't already been
        // set programmatically by the publisher.
        if Self.debugSettings == nil {
            let debugSettings = UMPDebugSettings()
            if let testDeviceIdentifiers = credentials?["testDeviceIdentifiers"] as? [String] {
                debugSettings.testDeviceIdentifiers = testDeviceIdentifiers
                log("Test device identifiers updated with backend config", level: .debug)
            }
            if let geographyRawValue = credentials?["geography"] as? Int,
               let geography = UMPDebugGeography(rawValue: geographyRawValue)
            {
                debugSettings.geography = geography
                log("Debug geography updated with backend config", level: .debug)
            }
            Self.debugSettings = debugSettings
        }
    }

    /// Sets up the module to make it ready to be used.
    /// - parameter configuration: A ``ModuleInitializationConfiguration`` for configuring the module.
    /// - parameter completion: A completion handler to be executed when the module is done initializing.
    /// An error should be passed if the initialization failed, whereas `nil` should be passed if it succeeded.
    public func initialize(configuration: ModuleInitializationConfiguration, completion: @escaping (Error?) -> Void) {
        // Configure the SDK and fetch initial consent status.
        // We don't report consent changes to the delegate here since we are restoring the info from whatever the SDK has saved.
        log("Requesting consent info update", level: .debug)
        let request = UMPRequestParameters()
        request.tagForUnderAgeOfConsent = ChartboostCore.analyticsEnvironment.isUserUnderage
        request.debugSettings = Self.debugSettings
        UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: request) { [weak self] error in
            if let error {
                self?.log("Consent info update failed with error: \(error)", level: .error)
            } else {
                self?.log("Consent info update succeeded", level: .info)
            }
        }
    }

    // MARK: - Consent

    /// Informs the CMP that the user has granted consent.
    /// This method should be used only when a custom consent dialog is presented to the user, thereby making the publisher
    /// responsible for the UI-side of collecting consent. In most cases ``showConsentDialog(_:from:completion:)`` should
    /// be used instead.
    /// If the CMP does not support custom consent dialogs or the operation fails for any other reason, the completion
    /// handler is executed with a `false` parameter.
    /// - parameter source: The source of the new consent. See the ``ConsentStatusSource`` documentation for more info.
    /// - parameter completion: Handler called to indicate if the operation went through successfully or not.
    public func grantConsent(source: ConsentStatusSource, completion: @escaping (_ succeeded: Bool) -> Void) {
        log("Granting consent is not supported", level: .warning)
        completion(false)   // Google User Messaging Platform does not support custom consent dialogs
    }

    /// Informs the CMP that the user has denied consent.
    /// This method should be used only when a custom consent dialog is presented to the user, thereby making the publisher
    /// responsible for the UI-side of collecting consent. In most cases ``showConsentDialog(_:from:completion:)``should
    /// be used instead.
    /// If the CMP does not support custom consent dialogs or the operation fails for any other reason, the completion
    /// handler is executed with a `false` parameter.
    /// - parameter source: The source of the new consent. See the ``ConsentStatusSource`` documentation for more info.
    /// - parameter completion: Handler called to indicate if the operation went through successfully or not.
    public func denyConsent(source: ConsentStatusSource, completion: @escaping (_ succeeded: Bool) -> Void) {
        log("Denying consent is not supported", level: .warning)
        completion(false)   // Google User Messaging Platform does not support custom consent dialogs
    }

    /// Informs the CMP that the given consent should be reset.
    /// If the CMP does not support the `reset()` function or the operation fails for any other reason, the completion
    /// handler is executed with a `false` parameter.
    /// - parameter completion: Handler called to indicate if the operation went through successfully or not.
    public func resetConsent(completion: @escaping (_ succeeded: Bool) -> Void) {
        // Reset all consents
        log("Resetting consent", level: .debug)
        UMPConsentInformation.sharedInstance.reset()
        // TODO: Need to call requestConsentInfoUpdate() again?
    }

    /// Instructs the CMP to present a consent dialog to the user for the purpose of collecting consent.
    /// - parameter type: The type of consent dialog to present. See the ``ConsentDialogType`` documentation for more info.
    /// If the CMP does not support a given type, it should default to whatever type it does support.
    /// - parameter viewController: The view controller to present the consent dialog from.
    /// - parameter completion: This handler is called to indicate whether the consent dialog was successfully presented or not.
    /// Note that this is called at the moment the dialog is presented, **not when it is dismissed**.
    public func showConsentDialog(_ type: ConsentDialogType, from viewController: UIViewController, completion: @escaping (_ succeeded: Bool) -> Void) {
        log("Showing \(type) consent dialog", level: .debug)

        DispatchQueue.main.async {  // according to UMP's documentation form methods must be called from the main queue
            switch type {
            case .concise:
                UMPConsentForm.loadAndPresentIfRequired(from: viewController) { [weak self] error in
                    if let error {
                        self?.log("Failed to show \(type) consent dialog due to error: \(error)", level: .error)
                    } else {
                        self?.log("Showed \(type) consent dialog", level: .info)
                    }
                }
                completion(true)
            case .detailed:
                UMPConsentForm.presentPrivacyOptionsForm(from: viewController) { [weak self] error in
                    if let error {
                        self?.log("Failed to show \(type) consent dialog due to error: \(error)", level: .error)
                    } else {
                        self?.log("Showed \(type) consent dialog", level: .info)
                    }
                }
                completion(true)
            default:
                self.log("Could not show consent dialog with unknown type: \(type)", level: .error)
                completion(false)
            }
        }
    }
}
