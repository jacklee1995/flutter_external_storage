#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint external_storage.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'external_storage'
  s.version          = '1.0.0'
  s.summary          = 'Storage volumes, file operations and file watching for Flutter.'
  s.description      = <<-DESC
iOS implementation of the external_storage Flutter plugin (storage volume information and settings access).
                       DESC
  s.homepage         = 'https://github.com/jacklee1995/flutter_external_storage'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'jcLee95' => '291148484@163.com' }
  s.source           = { :path => '.' }
  s.source_files = 'external_storage/Sources/external_storage/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {'external_storage_privacy' => ['external_storage/Sources/external_storage/PrivacyInfo.xcprivacy']}
end
