module VagrantPlugins
  module ProviderKvm
    module Action
      class SetName
        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant::action::vm::setname")
          @app = app
        end

        def call(env)
          name = env[:machine].provider_config.name

          if !name
            prefix = env[:root_path].basename.to_s
            prefix.gsub!(/[^-a-z0-9_]/i, "")
            name = prefix + "_#{Time.now.to_i}"
          end

          # @todo raise error if name is taken in kvm
          # @todo don't set the name if the vm already has a name

          @logger.info("Setting the name of the VM: #{name}")
          env[:machine].provider.driver.set_name(name)

          @app.call(env)
        end

      end
    end
  end
end
