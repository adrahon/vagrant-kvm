require "pathname"

module VagrantPlugins
  module ProviderKvm
    module Util
      util_root = Pathname.new(File.expand_path("../util", __FILE__))
      autoload :DefinitionAttributes, util_root.join("definition_attributes")
      autoload :VmDefinition, util_root.join("vm_definition")
      autoload :NetworkDefinition, util_root.join("network_definition")
      autoload :KvmTemplateRenderer, util_root.join("kvm_template_renderer")
      autoload :Commands, util_root.join("commands")
      autoload :DiskInfo, util_root.join("disk_info")
    end
  end
end
