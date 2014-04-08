module VagrantPlugins
  module ProviderKvm
    module Action
      class PrepareNFSSettings
        def initialize(app,env)
          @app = app
          @logger = Log4r::Logger.new("vagrant::action::vm::nfs")
        end

        def call(env)
          @app.call(env)
          @machine = env[:machine]

          if using_nfs?
            env[:nfs_host_ip]    = read_host_ip
            env[:nfs_machine_ip] = read_machine_ip
          end
        end

        def using_nfs?
            @machine.config.vm.synced_folders.any? { |_, opts| opts[:type] == :nfs }
        end

        # Returns the IP address of the host
        #
        # @param [Machine] machine
        # @return [String]
        def read_host_ip
          ip = read_machine_ip
          base_ip = ip.split(".")
          base_ip[3] = "1"
          base_ip.join(".")
        end

        # Returns the IP address of the guest by looking at the first
        # enabled host only network.
        #
        # @return [String]
        def read_machine_ip
          @machine.provider.driver.read_machine_ip
        end

      end
    end
  end
end
