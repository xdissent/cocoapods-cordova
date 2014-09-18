Pod::Spec.new do |spec|
  spec.name         = 'A'
  spec.version      = '0.0.1'
  spec.requires_arc = true
  spec.platform     = :ios, '7.0'
  spec.source       = {:git => 'https://github.com/example/A.git'}
  spec.source_files = 'src/ios/A/A.{h,m}'
  spec.public_header_files = 'src/ios/A/A.h'

  spec.dependency 'Cordova'
  spec.dependency 'CordovaPlugin-file'
  spec.dependency 'AFNetworking'
end