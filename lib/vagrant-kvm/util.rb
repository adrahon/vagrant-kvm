require "pathname"

module VagrantPlugins
  module ProviderKvm
    module Util
      util_root = Pathname.new(File.expand_path("../util", __FILE__))
      autoload :VmDefinition, util_root.join("vm_definition")
      autoload :NetworkDefinition, util_root.join("util/network_definition")
    end
  end
end
