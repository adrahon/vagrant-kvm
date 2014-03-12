module VagrantPlugins
  module ProviderKvm
    module Action
      class Suspend
        def initialize(app, env)
          @app = app
        end

        def call(env)
          if env[:machine].provider.state.id == :running
            env[:ui].info I18n.t("vagrant.actions.vm.suspend.suspending")
            if env[:machine].provider_config.force_suspend
              env[:machine].provider.driver.suspend
            elsif  env[:machine].provider.driver.can_save?
              env[:machine].provider.driver.save
            else
              env[:ui].warn ("Suspend is not supported. use pause instead.")
              env[:machine].provider.driver.suspend
            end
          end

          @app.call(env)
        end
      end
    end
  end
end
