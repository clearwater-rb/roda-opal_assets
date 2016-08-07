# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'roda/opal_assets/version'

Gem::Specification.new do |spec|
  spec.name          = "roda-opal_assets"
  spec.version       = Roda::OpalAssets::VERSION
  spec.authors       = ["Jamie Gaskins"]
  spec.email         = ["jgaskins@gmail.com"]

  spec.summary       = %q{Compile Opal assets trivially on Roda}
  spec.homepage      = "https://github.com/clearwater-rb/roda-opal_assets"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "opal", "~> 0.9", "< 0.11.0"
  spec.add_runtime_dependency "sprockets", "~> 3.6.0"
  spec.add_runtime_dependency "roda"
  spec.add_runtime_dependency "uglifier", "~> 3.0"

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
