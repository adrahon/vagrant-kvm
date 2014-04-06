module VagrantPlugins
  module ProviderKvm
    module Action
      # Checks that the libvirt/kvm/qemu environment is ready to be used.
      class CheckKvm
        def initialize(app, env)
          @app = app
        end

        def call(env)
          # This verifies that kvm/qemu is installed, the environment is
          # set-up and the driver is ready to function. If not, then an
          # exception will be raised which will break us out of execution
          # of the middleware sequence.
          env[:machine].provider.driver.verify!

          # Carry on.
          @app.call(env)
        end
      end
    end
  end
end
