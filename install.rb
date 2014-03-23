#!/usr/bin/env ruby
require "#{File.dirname(__FILE__)}/lib/vagrant-kvm/version"

version = VagrantPlugins::ProviderKvm::VERSION
p version
system('gem build vagrant-kvm.gemspec')
system("vagrant plugin install vagrant-kvm-%s.gem"%version)
