// Copyright 2023-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostCoreSDK
import UserMessagingPlatform

private let IABUserDefaultsTCFKey = "IABTCF_TCString"
private let IABUserDefaultsGPPKey = "IABGPP_HDR_GppString"
private let IABUserDefaultsUSPKey = "IABUSPrivacy_String"

/// Chartboost Core Consent Usercentrics adapter.
@objc(CBCGoogleCMPAdapter)
@objcMembers
public final class GoogleCMPAdapter: NSObject, InitializableModule, ConsentAdapter {

    /// A flag indicating if the adapter is registered as an observer for changes on UserDefault's consent-related keys.
    private var isObservingConsentChanges = false

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
            && UMPConsentInformation.sharedInstance.consentStatus == .required
    }

    /// The current consent status determined by the CMP.
    public var consentStatus: ConsentStatus {
        // UMPConsentInformation.sharedInstance.consentStatus doesn't indicate if the user has consented or not.
        // See https://developers.google.com/admob/ios/privacy/gdpr
        return .unknown
    }

    /// Individualized consent status per partner SDK.
    ///
    /// The keys for advertising SDKs should match Chartboost Mediation partner adapter ids.
    public var partnerConsentStatus: [String: ConsentStatus] {
        // Google User Messaging Platform does not provide consent status per partner beyond what's available on the IAB UserDefaults keys.
        [:]
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
        consents[.gpp] = UserDefaults.standard.string(forKey: IABUserDefaultsGPPKey).map(ConsentValue.init(stringLiteral:))
        consents[.tcf] = UserDefaults.standard.string(forKey: IABUserDefaultsTCFKey).map(ConsentValue.init(stringLiteral:))
        consents[.usp] = UserDefaults.standard.string(forKey: IABUserDefaultsUSPKey).map(ConsentValue.init(stringLiteral:))
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

    deinit {
        stopObservingConsentChanges()
    }

    /// Sets up the module to make it ready to be used.
    /// - parameter configuration: A ``ModuleInitializationConfiguration`` for configuring the module.
    /// - parameter completion: A completion handler to be executed when the module is done initializing.
    /// An error should be passed if the initialization failed, whereas `nil` should be passed if it succeeded.
    public func initialize(configuration: ModuleInitializationConfiguration, completion: @escaping (Error?) -> Void) {
        // Configure the SDK and fetch initial consent status.
        // We don't report consent changes to the delegate here since we are restoring the info from whatever the SDK has saved.
        log("Requesting consent info update", level: .debug)
        updateConsentInfo { [weak self] error in
            completion(error)
            self?.startObservingConsentChanges()
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
        updateConsentInfo(completion: nil)
        completion(true)
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

    // MARK: - Helpers

    private func updateConsentInfo(completion: ((Error?) -> Void)?) {
        let request = UMPRequestParameters()
        request.tagForUnderAgeOfConsent = ChartboostCore.analyticsEnvironment.isUserUnderage
        request.debugSettings = Self.debugSettings
        UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: request) { [weak self] error in
            if let error {
                self?.log("Consent info update failed with error: \(error)", level: .error)
            } else {
                self?.log("Consent info update succeeded", level: .info)
            }
            completion?(error)
        }
    }

    private func startObservingConsentChanges() {
        UserDefaults.standard.addObserver(self, forKeyPath: IABUserDefaultsTCFKey, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: IABUserDefaultsGPPKey, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: IABUserDefaultsUSPKey, context: nil)
        isObservingConsentChanges = true
    }

    private func stopObservingConsentChanges() {
        // Note it is an error to try to remove an observer that hasn't been previously registered as such
        if isObservingConsentChanges {
            UserDefaults.standard.removeObserver(self, forKeyPath: IABUserDefaultsTCFKey)
            UserDefaults.standard.removeObserver(self, forKeyPath: IABUserDefaultsGPPKey)
            UserDefaults.standard.removeObserver(self, forKeyPath: IABUserDefaultsUSPKey)
        }
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        log("User defaults change, key: '\(keyPath ?? "")' value: \(UserDefaults.standard.value(forKey: keyPath ?? "") ?? "")", level: .trace)

        switch keyPath {
        case IABUserDefaultsTCFKey:
            delegate?.onConsentChange(standard: .tcf, value: consents[.tcf])
        case IABUserDefaultsGPPKey:
            delegate?.onConsentChange(standard: .gpp, value: consents[.gpp])
        case IABUserDefaultsUSPKey:
            delegate?.onConsentChange(standard: .usp, value: consents[.usp])
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}
