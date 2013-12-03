require "pathname"

module VagrantPlugins
  module ProviderKvm
    module Util
      util_root = Pathname.new(File.expand_path("../util", __FILE__))
      autoload :VmDefinition, util_root.join("vm_definition")
      autoload :NetworkDefinition, util_root.join("network_definition")
      autoload :KvmTemplateRenderer, util_root.join("kvm_template_renderer")
      autoload :Commands, util_root.join("commands")
    end
  end
end
