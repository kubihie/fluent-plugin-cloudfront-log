# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-cloudfront-log"
  spec.version       = "0.0.5"
  spec.authors       = ["kubihie"]
  spec.email         = ["kubihie@gmail.com"]

  spec.summary       = %q{AWS CloudFront log input plugin.}
  spec.description   = %q{AWS CloudFront log input plugin for fluentd.}
  spec.homepage      = "https://github.com/kubihie/fluent-plugin-cloudfront-log"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "fluentd", "~> 0"
  spec.add_dependency "aws-sdk", "~> 2.1"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency 'test-unit', "~> 2"
end
