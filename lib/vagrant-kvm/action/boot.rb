module VagrantPlugins
  module ProviderKvm
    module Action
      class Boot
        def initialize(app, env)
          @app = app
        end

        def call(env)
          @env = env

          # Start up the VM
          env[:ui].info I18n.t("vagrant.actions.vm.boot.booting")
          env[:machine].provider.driver.start

          @app.call(env)
        end

      end
    end
  end
end
