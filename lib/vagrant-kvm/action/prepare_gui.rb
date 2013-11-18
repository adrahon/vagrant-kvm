module VagrantPlugins
  module ProviderKvm
    module Action
      class PrepareGui
        def initialize(app, env)
          @app = app
        end

        def call(env)
          config = env[:machine].provider_config
          if config.gui
            driver = env[:machine].provider.driver
            driver.gui = true
            driver.vnc_port = config.vnc_port if config.vnc_port
            driver.vnc_autoport = config.vnc_autoport if config.vnc_autoport
          end
          @app.call(env)
        end
      end
    end
  end
end
