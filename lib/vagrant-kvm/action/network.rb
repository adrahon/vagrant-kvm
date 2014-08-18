require "log4r"

module VagrantPlugins
  module ProviderKvm
    module Action
      # This middleware class configures networking
      class Network

        def initialize(app, env)
          @logger = Log4r::Logger.new("vagrant::plugins::kvm::network")
          @app    = app
          @hosts = []
        end

        def call(env)
          @env = env

          @env[:ui].info I18n.t("vagrant.actions.vm.network.preparing")
          create_or_start_default_network!
          create_or_update_private_network!

          @app.call(env)
        end

        private

        def create_or_start_default_network!
          # default NAT network/nic
          @env[:machine_ip] = select_default_ip
          @env[:machine].provider.driver.create_network(
            :name  => get_network_name(@env[:machine_ip]), 
            :hosts => [{
              :mac   => @env[:machine].provider.driver.read_mac_address,
              :name => get_host_name,
              :ip   => @env[:machine_ip]
            }]
          )
        end

        def create_or_update_private_network!
          # enumerate private network options
          private_network_options = []
          @env[:machine].config.vm.networks.each do |type, network_options|
            private_network_options << network_options if type == :private_network
          end

          private_network_options.each_with_index do |option,index|
            option = set_private_network_options(option)
            if check_private_network_segment(option)
              add_private_network_host(option, index)
            else
              @logger.info ("Ignore invalid private network definition.")
            end
          end
        end

        def get_host_name
          if @env[:machine].provider.driver.name
            @env[:machine].provider.driver.name
          elsif @env[:machine].provider_config.name
            @env[:machine].provider_config.name
          else
            "nic-"+Time.now.to_i.to_s
          end
        end

        def get_network_name(ip)
          subnet = ip.split(".")[2].to_s
          default_subnet = @env[:machine].provider.driver.get_default_ip.split(".")[2].to_s
          if subnet == default_subnet
            "vagrant"
          else
            "vagrant-"+subnet
          end
        end

        def add_private_network_host(option, index)
            mac = random_mac
            option[:hosts]= [{
              :mac => mac,
              :name => get_host_name,
              :ip => option[:ip]
            }]
            addr = option[:ip].split(".")
            nic = { :mac => mac,
                    :name=> "eth"+(index+1).to_s,
                    :network => "vagrant-"+addr[2].to_s,
                    :type => 'network',
                    :model => 'virtio'}
            @env[:machine].provider.driver.add_nic(nic)
            @env[:machine].provider.driver.create_network(option)
        end

        def select_default_ip
          ip_addresses = @env[:machine].provider.driver.list_default_network_ips
          candidate = ""
          loop do
            candidate = 2 + Random.rand(253)
            candidate = "192.168.123.%d" % candidate
           break unless ip_addresses.include?(candidate)
          end
          @logger.info("select #{candidate} as default ip address for nic")
          candidate
        end

        # check options[:ip] is not reserved?
        def check_private_network_segment(options)
          if options.has_key?(:ip)
            addr = options[:ip].split(".")
            # except for virbr{0|1} and hostonly network
            if @env[:machine].provider.driver.host_ubuntu?
              return false if addr[2] == '122' || addr[2] == '100' || addr[2] == '123'
            else
              return false if addr[2] == '123'
            end
          end
        true
        end

        def set_private_network_options(options)
          if options.has_key?(:ip)
            addr = options[:ip].split(".")
            addr[3] = "1"
            base_ip = addr.join(".")
            addr[3] = "100"
            start_ip = addr.join(".")
            addr[3] = "200"
            end_ip = addr.join(".")
            range = {
              :start => start_ip,
              :end   => end_ip }
            options = {
              :base_ip => base_ip,
              :netmask => "255.255.255.0",
              :range   => range,
              :name    => "vagrant-" + addr[2].to_s,
              :domain_name => "vagrant.local"
            }.merge(options)
          end
          options
        end

        def format_mac(mac)
          return nil unless mac
          if mac.length == 12
            mac = mac[0..1] + ":" + mac[2..3] + ":" +
              mac[4..5] + ":" + mac[6..7] + ":" +
              mac[8..9] + ":" + mac[10..11]
          end
          mac
        end

      end
    end
  end
end
