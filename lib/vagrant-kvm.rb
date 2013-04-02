require "pathname"

require "vagrant-kvm/plugin"

module VagrantPlugins
  module ProviderKvm
    lib_path = Pathname.new(File.expand_path("../vagrant-kvm", __FILE__))
    autoload :Action, lib_path.join("action")
    autoload :Driver, lib_path.join("driver/driver")
    autoload :Errors, lib_path.join("errors")

    module Util
      autoload :VmDefinition, lib_path.join("util/vm_definition")
      autoload :NetworkDefinition, lib_path.join("util/network_definition")
    end

    # This returns the path to the source of this plugin.
    #
    # @return [Pathname]
    def self.source_root
      @source_root ||= Pathname.new(File.expand_path("../../", __FILE__))
    end
  end
end
