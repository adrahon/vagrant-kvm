require 'vagrant/util/template_renderer'

module VagrantPlugins
  module ProviderKvm
    module Util
      # For TemplateRenderer
      include Vagrant::Util
      class KvmTemplateRenderer < TemplateRenderer

        # Returns the full path to the template, taking into accoun the gem directory
        # and adding the `.erb` extension to the end.
        #
        # @return [String]
        def full_template_path
          ProviderKvm.source_root.join('templates', "#{template}.erb").to_s.squeeze("/")
        end
      end
    end
  end
end
