module VagrantPlugins
  module ProviderKvm
    module Action
      class NewMACAddress
        def initialize(app, env)
          @app = app
        end

        def call(env)
          # Generate a new mac address for the vm
          env[:ui].info I18n.t("vagrant_kvm.new_mac_address")
          env[:machine].provider.driver.set_mac_address(
            env[:machine].provider.driver.generate_mac_address)


          @app.call(env)
        end
      end
    end
  end
end
