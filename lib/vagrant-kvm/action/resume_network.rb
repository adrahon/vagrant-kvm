module VagrantPlugins
  module ProviderKvm
    module Action
      class ResumeNetwork
        def initialize(app, env)
          @app = app
        end

        def call(env)
          interfaces = env[:machine].provider.driver.read_network_interfaces
          interfaces.each do |nic|
            next unless nic[:type] == :network

            network_name = nic[:network].to_s
            state = env[:machine].provider.driver.network_state?(network_name)
            unless state
              # start network and related services such as forward and nfs
              env[:machine].provider.driver.start_network(network_name)
              env[:action_runner].run(ForwardPorts, env)
            end
          end

          @app.call(env)
        end
      end
    end
  end
end
