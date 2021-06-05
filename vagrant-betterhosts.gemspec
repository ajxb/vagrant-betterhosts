# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vagrant-betterhosts/version'

Gem::Specification.new do |s|
  s.name          = 'vagrant-betterhosts'
  s.version       = VagrantPlugins::BetterHosts::VERSION
  s.platform      = Gem::Platform::RUBY
  s.authors       = ['Daniele Scasciafratte']
  s.email         = ['mte90net@gmail.com']
  s.description   = "Enables Vagrant to update hosts file on the host machine with betterhosts"
  s.summary       = s.description
  s.homepage      = 'https://github.com/betterhosts/vagrant'
  s.license       = 'MIT'

  s.files         = `git ls-files`.split($/)
  s.files        += Dir.glob("lib/vagrant-betterhosts/bundle/*")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.add_development_dependency 'bundler', '~> 1.3'
  s.add_development_dependency 'rake'
end
