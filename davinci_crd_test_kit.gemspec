require_relative 'lib/davinci_crd_test_kit/version'

Gem::Specification.new do |spec|
  spec.name          = 'davinci_crd_test_kit'
  spec.version       = DaVinciCRDTestKit::VERSION
  spec.authors       = ['Stephen MacVicar', 'Vanessa Fotso', 'Emily Michaud']
  spec.email         = ['inferno@groups.mitre.org']
  spec.summary       = 'DaVinci CRD Test Kit'
  spec.description   = 'DaVinci CRD Test Kit'
  spec.homepage      = 'https://github.com/inferno-framework/davinci-crd-test-kit'
  spec.license       = 'Apache-2.0'
  spec.add_runtime_dependency 'inferno_core', '~> 0.6.15'
  spec.add_runtime_dependency 'smart_app_launch_test_kit', '~> 0.6.4'
  spec.add_runtime_dependency 'tls_test_kit', '~> 0.3.0'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.3.6')
  spec.metadata['inferno_test_kit'] = 'true'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.files = `[ -d .git ] && git ls-files -z lib config/presets LICENSE`.split("\x0")

  spec.require_paths = ['lib']
end
