#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |spec|
  spec.name             = 'flutter_downloader'
  spec.version          = '0.0.1'
  spec.summary          = 'A plugin to create and manage bankground download tasks'
  spec.homepage         = 'https://github.com/hnvn/flutter_downloader'
  spec.license          = { :file => '../LICENSE' }
  spec.author           = { 'HungHD' => 'hunghd.yb@gmail.com' }
  spec.source           = { :path => '.' }
  spec.source_files = 'Classes/**/*'
  spec.public_header_files = 'Classes/**/*.h'
  spec.dependency 'Flutter'
  spec.ios.library = 'sqlite3'
  spec.ios.resource_bundle = { 'FlutterDownloaderDatabase' => 'Assets/download_tasks.sql' }
  spec.ios.deployment_target = '9.0'
end
