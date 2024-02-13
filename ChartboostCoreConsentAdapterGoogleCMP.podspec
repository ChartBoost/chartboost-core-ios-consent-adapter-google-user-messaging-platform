Pod::Spec.new do |spec|
  spec.name        = 'ChartboostCoreConsentAdapterGoogleCMP'
  spec.version     = '0.2.1.0.0'
  spec.license     = { :type => 'MIT', :file => 'LICENSE.md' }
  spec.homepage    = 'https://github.com/ChartBoost/chartboost-core-ios-consent-adapter-google-cmp'
  spec.authors     = { 'Chartboost' => 'https://www.chartboost.com/' }
  spec.summary     = 'Chartboost Core iOS SDK Google CMP Adapter.'
  spec.description = 'Google CMP adapters for mediating through Chartboost Core.'

  # Source
  spec.module_name  = 'ChartboostCoreConsentAdapterGoogleCMP'
  spec.source       = { :git => 'https://github.com/ChartBoost/chartboost-core-ios-consent-adapter-google-cmp.git', :tag => spec.version }
  spec.source_files = 'Source/**/*.{swift}'

  # Minimum supported versions
  spec.swift_version         = '5.3'
  spec.ios.deployment_target = '11.0'

  # System frameworks used
  spec.ios.frameworks = ['Foundation', 'UIKit']
  
  # This adapter is compatible with Chartboost Core 0.4+ versions of the SDK.
  spec.dependency 'ChartboostCoreSDK', '~> 0.4'

  # CMP SDK and version that this adapter is certified to work with.
  spec.dependency 'GoogleUserMessagingPlatform', '~> 2.1.0'

  # The CMP SDK is a static framework which requires the static_framework option.
  spec.static_framework = true
end
