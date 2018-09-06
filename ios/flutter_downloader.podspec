#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_downloader'
  s.version          = '0.0.1'
  s.summary          = 'A plugin to create and manage bankground download tasks'
  s.description      = <<-DESC
A plugin to create and manage bankground download tasks
                       DESC
  s.homepage         = 'https://github.com/hnvn/flutter_downloader'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'HungHD' => 'hunghd.yb@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.ios.library = 'sqlite3'
  s.ios.resource_bundle = { 'FlutterDownloaderDatabase' => 'Assets/download_tasks.sql' }
  
  s.ios.deployment_target = '8.0'
end

