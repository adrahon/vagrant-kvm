module VagrantPlugins
  module ProviderKvm
    module Action
      class PrepareGui
        def initialize(app, env)
          @app = app
        end

        def call(env)
          if env[:machine].provider_config.gui
            env[:machine].provider.driver.set_gui
          end
          @app.call(env)
        end
      end
    end
  end
end
