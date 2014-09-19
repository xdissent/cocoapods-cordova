Pod::Spec.new do |spec|
  spec.name         = 'B'
  spec.version      = '0.0.1'
  spec.requires_arc = true
  spec.platform     = :ios, '7.0'
  spec.source       = {:git => 'https://github.com/example/B.git'}
  spec.source_files = 'B/B.{h,m}'
  spec.public_header_files = 'B/B.h'

  spec.dependency 'Cordova'
  spec.dependency 'CordovaPlugin-file'
  spec.dependency 'AFNetworking'
end