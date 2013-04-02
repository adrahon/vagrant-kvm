require "vagrant"

module VagrantPlugins
  module ProviderKvm
    module Errors
      class VagrantKVMError < Vagrant::Errors::VagrantError
        error_namespace("vagrant_kvm.errors")
      end
    end
  end
end
