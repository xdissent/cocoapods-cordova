# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods_cordova.rb'

Gem::Specification.new do |spec|
  spec.name          = "cocoapods-cordova"
  spec.version       = CocoapodsCordova::VERSION
  spec.authors       = ["Greg Thornton"]
  spec.email         = ["xdissent@me.com"]
  spec.description   = %q{A short description of cocoapods-cordova.}
  spec.summary       = %q{A longer description of cocoapods-cordova.}
  spec.homepage      = "https://github.com/xdissent/cocoapods-cordova"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "cocoapods", "~> 0.34.0.rc1"
  spec.add_runtime_dependency "cordova-packager", "~> 1.0.0"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
