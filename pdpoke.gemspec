# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pdpoke/version'

Gem::Specification.new do |spec|
  spec.name          = "pdpoke"
  spec.version       = PDPoke::VERSION
  spec.authors       = ["John Slee"]
  spec.email         = ["john.slee@fairfaxmedia.com.au"]

  spec.summary       = %q{Poke the PagerDuty API}
  spec.description   = %q{Poke the PagerDuty API}
  spec.homepage      = "https://github.com/fairfaxmedia/pdpoke"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "pager_duty-connection", "~> 0.2"
  spec.add_runtime_dependency "thor", "~> 0.19"
  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
end
