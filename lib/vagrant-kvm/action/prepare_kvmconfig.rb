module VagrantPlugins
  module ProviderKvm
    module Action
      class PrepareKvmConfig
        def initialize(app, env)
          @app = app
        end

        def call(env)
          config = env[:machine].provider_config
          if config.gui
            driver = env[:machine].provider.driver
            driver.set_gui(config.vnc_port, config.vnc_autoport, config.vnc_password)
          end
          # set disk_bus customize
          disk_bus = env[:machine].provider_config.disk_bus
          env[:machine].provider.driver.set_diskbus(disk_bus) if disk_bus
          @app.call(env)
        end
      end
    end
  end
end
