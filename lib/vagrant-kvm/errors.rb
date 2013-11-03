require "vagrant"

module VagrantPlugins
  module ProviderKvm
    module Errors
      class VagrantKVMError < Vagrant::Errors::VagrantError
        error_namespace("vagrant_kvm.errors")
      end
      class KvmNoConnection < VagrantKVMError
        error_key(:kvm_no_connection)
      end
      class KvmInvalidVersion < VagrantKVMError
        error_key(:kvm_invalid_version)
      end
      class KvmNoQEMUBinary < VagrantKVMError
        error_key(:kvm_no_qemu_binary)
      end
      class KvmFailImageConversion < VagrantKVMError
        error_key(:kvm_fail_image_conversion)
      end
    end
  end
end
