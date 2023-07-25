# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vagrant-betterhosts/version'

Gem::Specification.new do |s|
  s.name          = 'vagrant-betterhosts'
  s.version       = VagrantPlugins::BetterHosts::VERSION
  s.platform      = Gem::Platform::RUBY
  s.authors       = ['Adam Butler']
  s.email         = ['adam.j.butler@protonmail.com']
  s.description   = 'Enables Vagrant to update hosts file on the host machine using the goodhosts cli tool'
  s.summary       = 'Vagrant plugin to manage the hosts file on the host machine'
  s.homepage      = 'https://github.com/ajxb/vagrant-betterhosts'
  s.license       = 'MIT'

  s.required_ruby_version     = ">= 2.5"
  s.files                 = `git ls-files`.split($/)
  s.files                += Dir.glob("lib/vagrant-betterhosts/bundle/*")
  s.executables           = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files            = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths         = ['lib']

  s.add_development_dependency 'bundler', '~> 1.3'
  s.add_development_dependency 'rake', '~> 13.0'

  s.add_runtime_dependency 'os', '~> 0.9'
end
