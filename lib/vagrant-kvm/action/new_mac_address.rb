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
          env[:machine].provider.driver.set_mac_address(random_mac)

          @app.call(env)
        end

        def random_mac
          rng = Random.new(Time.now.to_i)
          mac = [0x52, 0x54, 0x00, # KVM Vendor prefix
                rng.rand(128),
                rng.rand(256),
                rng.rand(256)]
          mac.map {|x| "%02x" % x}.join(":")
        end
      end
    end
  end
end
