require 'spec_helper'

module VagrantPlugins::ProviderKvm::Errors
  describe VagrantPlugins::ProviderKvm::Errors do
    it "has translations for all errors" do
      # Load the translations
      VagrantPlugins::ProviderKvm::Plugin.setup_i18n

      descendants = ObjectSpace.each_object(Class).select { |klass| klass < VagrantKVMError }

      all_interpolations = {
        required: "",
        cause: "",
        actual: "",
        cmd: "",
        res: "",
      }

      descendants.each do |klass|
        msg = klass.new(all_interpolations).message
        msg.should_not include("translation missing")
      end
    end
  end
end
