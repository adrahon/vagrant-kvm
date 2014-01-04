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

          env[:nfs_host_ip]    = read_host_ip(env[:machine])
          env[:nfs_machine_ip] = read_machine_ip(env[:machine])

        end

        # Returns the IP address of the first host only network adapter
        #
        # @param [Machine] machine
        # @return [String]
        def read_host_ip(machine)
          ip = read_machine_ip(machine)
          if ip
            base_ip = ip.split(".")
            base_ip[3] = "1"
            return base_ip.join(".")
          end

          # If no private network configuration, return default ip
          "192.168.123.1"
        end

        # Returns the IP address of the guest by looking at the first
        # enabled host only network.
        #
        # @return [String]
        def read_machine_ip(machine)
          machine.config.vm.networks.each do |type, options|
            if type == :private_network && options[:ip].is_a?(String)
              return options[:ip]
            end
          end

          # XXX duplicated with network.rb default
          # If no private network configuration, return default ip
          "192.168.123.10"
        end
      end
    end
  end
end
