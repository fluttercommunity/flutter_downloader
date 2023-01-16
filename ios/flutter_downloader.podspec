#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |spec|
  spec.name             = 'flutter_downloader'
  spec.version          = '0.0.2'
  spec.summary          = 'A plugin to create and manage background download tasks'
  spec.homepage         = 'https://github.com/fluttercommunity/flutterdownloader'
  spec.license          = { :file => '../LICENSE' }
  spec.author           = { 'HungHD' => 'hunghd.yb@gmail.com' }
  spec.source           = { :path => '.' }
  spec.source_files = 'Classes/**/*'
  spec.dependency 'Flutter'
  spec.platform = :ios, '9.0'

  # Flutter.framework does not contain a i386 slice.
  spec.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  spec.swift_version = '5.0'
end
