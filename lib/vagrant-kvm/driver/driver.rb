require 'libvirt'
require 'log4r'
require 'pathname'
require "rexml/document"

module VagrantPlugins
  module ProviderKvm
    module Driver
      class Driver
        # This is raised if the VM is not found when initializing
        # a driver with a UUID.
        class VMNotFound < StandardError; end

        include Util
        include Errors
        include Util::Commands

        # enum for states return by libvirt
        VM_STATE = [
          :no_state,
          :running,
          :blocked,
          :paused,
          :shutdown,
          :shutoff,
          :crashed]

        # The Name of the virtual machine we represent
        attr_reader :name

        # The UUID of the virtual machine we represent
        attr_reader :uuid

        # Vagrant 1.5.x pool migration
        attr_reader :pool_migrate

        def initialize(uuid=nil)
          @logger = Log4r::Logger.new("vagrant::provider::kvm::driver")
          @uuid = uuid
          @virsh_path = "virsh"
          @pool_migrate = false

          load_kvm_module!
          connect_libvirt_qemu!

          if @uuid
            # Verify the VM exists, and if it doesn't, then don't worry
            # about it (mark the UUID as nil)
            raise VMNotFound if !vm_exists?(@uuid)
          end
        end

        # create empty volume in storage pool
        # args: disk_name, capacity, path, image_type, box_pool, box_path,
        #       backing, owner, group, mode, label
        def create_volume(args={})
          args = { # default values
            :owner => '-1',
            :group => '-1',
            :mode  => '0744',
            :label => 'virt_image_t',
            :backing => false
          }.merge(args)
          msg = "Creating volume #{args[:disk_name]}"
          msg += " backed by volume #{args[:box_path]}" if args[:backing]
          capacity = args[:capacity]
          @logger.info(msg)
          storage_vol_xml = <<-EOF
          <volume>
            <name>#{args[:disk_name]}</name>
            <allocation>0</allocation>
            <capacity unit="#{capacity[:unit]}">#{capacity[:size]}</capacity>
            <target>
              <path>#{args[:path]}</path>
              <format type='#{args[:image_type]}'/>
              <permissions>
                <owner>#{args[:owner]}</owner>
                <group>#{args[:group]}</group>
                <mode>#{args[:mode]}</mode>
                <label>#{args[:label]}</label>
              </permissions>
            </target>
            EOF

          if args[:backing]
            storage_vol_xml += <<-EOF
            <backingStore>
              <path>#{args[:box_path]}</path>
              <format type='#{args[:image_type]}'/>
            </backingStore>
           EOF
          end
          storage_vol_xml += "</volume>"

          @logger.debug "Creating volume with XML:\n#{storage_vol_xml}"
          if args[:backing]
            vol = @pool.create_volume_xml(storage_vol_xml)
          else
            pool = @conn.lookup_storage_pool_by_name(args[:box_pool])
            clonevol = pool.lookup_volume_by_path(args[:box_path])
            # create_volume_xml_from() can convert disk image type automatically.
            vol = @pool.create_volume_xml_from(storage_vol_xml, clonevol)
          end
          @pool.refresh
        end

        def reset_volume_permission(userid, groupid)
          @logger.info("Revert image owner to #{userid}:#{groupid}")
          domain = @conn.lookup_domain_by_uuid(@uuid)
          definition = Util::VmDefinition.new(domain.xml_desc)
          volume_path = definition.attributes[:disk]
          run_root_command("chown #{userid}:#{groupid} " + volume_path)
          run_root_command("chmod 660 " + volume_path)
        end

        def delete
          cleanup_networks
          domain = @conn.lookup_domain_by_uuid(@uuid)
          definition = Util::VmDefinition.new(domain.xml_desc)
          volume = @pool.lookup_volume_by_path(definition.attributes[:disk])
          volume.delete
          # XXX remove pool if empty?
          @pool.refresh
          # remove any saved state
          domain.managed_save_remove if domain.has_managed_save?
          domain.undefine
        end

        def find_box_disk(xml)
          definition = File.open(xml) { |f|
            Util::VmDefinition.new(f.read) }
          definition.attributes[:disk]
        end

        # Halts the virtual machine
        def halt
          domain = @conn.lookup_domain_by_uuid(@uuid)
          domain.destroy
        end

        # Imports the VM
        #
        # @param [String] definition Path to the VM XML file.
        # @param [String] volume_name Name of the imported volume
        # @param [Hash]   attributes
        def import(box_xml_filename, volume_name, args={})
          @logger.info("Importing VM #{@name}")
          # create vm definition from xml
          definition = File.open(box_xml_filename) { |f| Util::VmDefinition.new(f.read) }
          volume_path = lookup_volume_path_by_name(volume_name)
          args = {
            :image_type => "qcow2",
            :qemu_bin => "/usr/bin/qemu",
            :disk => volume_path,
            :network => 'vagrant',
            :name => @name,
            :uuid => nil,
            :mac => generate_mac_address
          }.merge(args)
          args.merge!(:virtio_rng => nil) if @conn.version.to_i < 1003000  # virtio_rng supported in 1.3.0+
          definition.update(args)
          # create vm
          @logger.info("Creating new VM")
          xml_definition = definition.as_xml
          @logger.debug("Creating new VM with XML config:\n#{xml_definition}")
          domain = @conn.define_domain_xml(xml_definition)
          domain.uuid
        end

        # Create network
        def create_network(config)
          # Get the network if it exists
          network_name = config[:name]
          hosts = config[:hosts]
          @logger.info("empty host!") unless hosts
          begin
            network = @conn.lookup_network_by_name(network_name)
            definition = Util::NetworkDefinition.new(network_name,
                                                     network.xml_desc)
            old_def    = Util::NetworkDefinition.new(network_name,
                                                     network.xml_desc)
            definition.update(config)
            @logger.info("Update network #{network_name}")
            @logger.debug("From:\n#{old_def.as_xml}")
            @logger.debug("TO:\n#{definition.as_xml}")

            # Only destroy existing network if config has changed. This is
            # necessary because other VM could be currently using this network
            # and will loose connectivity if the network is destroyed.
            if network.active?
              @logger.info "Reusing existing configuration for #{network_name}"
              update_command = Libvirt::Network::NETWORK_UPDATE_COMMAND_ADD_LAST
              hosts.each do |host|
                if old_def.already_exist_host?(host)
                  update_command = Libvirt::Network::NETWORK_UPDATE_COMMAND_MODIFY
                end
              end
              if update_command == Libvirt::Network::NETWORK_UPDATE_COMMAND_MODIFY
                  @logger.info ("Updating network #{network_name} using UPDATE_COMMAND_MODIFY")
              else
                  @logger.info ("Updating network #{network_name} using UPDATE_COMMAND_ADD_LAST")
             end

             network.update(update_command,
              Libvirt::Network::NETWORK_SECTION_IP_DHCP_HOST,
              -1,
              definition.as_host_xml,
              Libvirt::Network::NETWORK_UPDATE_AFFECT_CURRENT
              )
             network.create unless network.active?
            else # network is not active
              @logger.info "Recreating network config for #{network_name}"
              network.undefine
              network = define_network(definition)
            end

          rescue Libvirt::RetrieveError
            # Network doesn't exist, create with defaults
            definition = Util::NetworkDefinition.new(network_name)
            definition.update(config)
            @logger.info("Creating network #{network_name}")
            @logger.debug("with\n#{definition.as_xml}")
            network = define_network(definition)
          end
        end

        def define_network(definition)
          xml = definition.as_xml
          @logger.debug "Defining new network with XML:\n#{xml}"
          network = @conn.define_network_xml(xml)
          network.create
          network
        end

        def get_default_ip
          "192.168.123.10"
        end

        def read_machine_ip
          if @uuid && vm_exists?(@uuid)
            begin
              domain = @conn.lookup_domain_by_uuid(@uuid)
              definition = Util::VmDefinition.new(domain.xml_desc)
              mac_address = definition.get(:mac)
              network_name = definition.get(:network)
              network = @conn.lookup_network_by_name(network_name)
              network_definition = Util::NetworkDefinition.new(network_name,
                                                     network.xml_desc)
              network_definition.get(:hosts).each do |host|
                return host[:ip] if mac_address == host[:mac]
              end
            rescue Libvirt::RetrieveError
              @logger.info("cannot get definition og #{@uuid}")
            end
          else
            @logger.debug("missing uuid? #{@uuid}")
          end
          get_default_ip
        end

        # Remove DHCP entries from Networks
        def cleanup_networks
          # Get list of NICs
          domain = @conn.lookup_domain_by_uuid(@uuid)
          definition = Util::VmDefinition.new(domain.xml_desc)
          nics = definition.get_all_nics
          nics.each do |nic|
            # for each nic remove dhcp entry from network
            network = @conn.lookup_network_by_name(nic[:network])
            network_def = Util::NetworkDefinition.new(nic[:network], network.xml_desc)

            @logger.info("Removing host entry from network #{nic[:network]}")
            @logger.debug("Removing #{nic[:mac]} defined as:\n#{network_def.get_host_xml(nic[:mac])}")
            # 2 should be Libvirt::Network::NETWORK_UPDATE_COMMAND_DELETE
            # but fails as undefined? XXX
            network.update(2,
              Libvirt::Network::NETWORK_SECTION_IP_DHCP_HOST,
              -1,
              network_def.get_host_xml(nic[:mac]),
              Libvirt::Network::NETWORK_UPDATE_AFFECT_CURRENT
              )

            # if no entries left, destroy and undefine the network
            network = @conn.lookup_network_by_name(nic[:network])
            network_def = Util::NetworkDefinition.new(nic[:network], network.xml_desc)
            if network_def.hosts.count == 0
              @logger.info("Network #{nic[:network]} has no hosts left, deleting.")
              network.destroy
              network.undefine
            end
          end
        end

        # Activate the driver's storage pool
        def activate_storage_pool(pool_name)
          # Get storage pool if it exists
          @pool = init_storage_pool(pool_name)
          # check neccesity of migrating to new storage pool format
          # this is happen when user has already used vagrant-kvm 0.1.5 and after
          # XXX needs clarification
          check_migrate_box_storage_pool
          @logger.info("Retrieving storage pool #{pool_name}")
        end

        # Initialize or Create a new storage pool
        def init_storage_pool(pool_name, pool_path='/tmp', dir_mode='0755')
          begin
            # Try to retrieve the storage pool
            pool = @conn.lookup_storage_pool_by_name(pool_name)
            @logger.info("Activating storage pool #{pool_name}")
            pool.create unless pool.active?
            pool.refresh
            pool
          rescue Libvirt::RetrieveError
            create_storage_pool(pool_name, pool_path, dir_mode)
          end
        end

        def create_storage_pool(pool_name, pool_path, dir_mode)
          @logger.info("Creating new storage pool #{pool_name} in #{pool_path}")
          # create dir if it doesn't exist
          FileUtils.mkpath(pool_path) unless Dir.exists?(pool_path)
          storage_pool_xml = <<-EOF
              <pool type="dir">
              <name>#{pool_name}</name>
              <target>
                <path>#{pool_path}</path>
                <permissions>
                 <owner>#{Process.uid}</owner>
                 <group>#{Process.gid}</group>
                 <mode>#{dir_mode}</mode>
                </permissions>
              </target>
              </pool>
          EOF
          # Create transient pool
          # Pools defined here will be removed after system reboot.
          @logger.debug("Creating storage pool with XML:\n #{storage_pool_xml}")
          begin
            pool = @conn.create_storage_pool_xml(storage_pool_xml)
            pool.build unless pool.active?
            pool.refresh
            pool
          rescue
            # check conflict and shutdown old pool
            defined_pool_list = @conn.list_storage_pools
            defined_pool_list.each do |defined_pool_name|
              defined_pool = @conn.lookup_storage_pool_by_name(defined_pool_name)
              defined_pool_doc = REXML::Document.new defined_pool.xml_desc
              defined_pool_path = File.expand_path(defined_pool_doc.elements["/pool/target/path"].text)
              @logger.debug("check whether conflict with #{defined_pool_name} on #{defined_pool_path}")
              if defined_pool_path == File.expand_path(pool_path)
                defined_pool.destroy
                pool = @conn.create_storage_pool_xml(storage_pool_xml)
                pool.build unless pool.active?
                pool.refresh
                return pool
              end
            end
            raise Errors::KvmFailStoragePool
          end
        end

        def check_migrate_box_storage_pool
          # Migration to new pool directory structure in vagrant 1.5.x
          # delete if created with <vagrant-1.4.x
          if Vagrant::VERSION >= "1.5.0"
            begin
              if @pool && @pool.persistent?
                # pool was made by vagrant-kvm-0.1.5 and before
                # vagrant-kvm-0.1.5 NOT working in vagrant 1.5.x
                # so need migrate
                @pool_migrate = true
              end
            rescue Libvirt::RetrieveError
              raise Errors::KvmFailStoragePool
            end
          end
        end

        def free_storage_pool(pool_name)
          begin
            pool = @conn.lookup_storage_pool_by_name(pool_name)
            # XXX  check reference counter for parallel action?
            pool.destroy
            pool.free
          rescue Libvirt::RetrieveError
            @logger.info("fail to free storage pool #{pool_name}")
          end
        end

        def storage_pool_path
          doc = REXML::Document.new @pool.xml_desc
          doc.elements["/pool/target/path"].text
        end

        def lookup_volume_path_by_name(volume_name)
          volume = @pool.lookup_volume_by_name(volume_name)
          volume.path
        end

        def list_all_network_ips
          interfaces = read_network_interfaces
          ips = []
          interfaces.each do |interface|
            next if interface.type == :user
            ips << list_network_ips(interface.name)
          end
          ips
        end

        def list_default_network_ips
          list_network_ips('vagrant')
        end

        def list_network_ips(network_name)
          begin
            network = @conn.lookup_network_by_name(network_name)
            network_definition = Util::NetworkDefinition.new(network_name, network.xml_desc)
            ips = []
            if network_definition
              ips = network_definition.hosts.map {|host| host[:ip]}
            end
            ips
          rescue Libvirt::RetrieveError
            @logger.info("error when getting network xml")
            []
          end
        end

        # Returns a list of network interfaces of the VM.
        #
        # @return [Hash]
        def read_network_interfaces
          domain = @conn.lookup_domain_by_uuid(@uuid)
          Util::VmDefinition.list_interfaces(domain.xml_desc)
        end

        def network_state?(network_name)
          begin
            network = @conn.lookup_network_by_name(network_name)
            network.active?
          rescue Libvirt::RetrieveError
            false
          end
        end

        def start_network(network_name)
          begin
            network = @conn.lookup_network_by_name(network_name)
            network.create unless network.active?
          rescue Libvirt::RetrieveError
            false
          end
        end

        # Returns a hostname of the guest
        # introduced from ruby-libvirt 0.5.0
        #
        # @return [String]
        def hostname?
          domain = @conn.lookup_domain_by_uuid(@uuid)
          domain.hostname
        end

        # reset the guest
        # introduced from ruby-libvirt 0.5.0
        def reset
          domain = @conn.lookup_domain_by_uuid(@uuid)
          domain.reset
        end

        def read_state
          domain = @conn.lookup_domain_by_uuid(@uuid)
          state, reason = domain.state
          # check if domain has been saved
          case VM_STATE[state]
          when :shutoff
            if domain.has_managed_save?
              return :saved
            end
            return :poweroff
          when :shutdown
            return :poweroff
          end
          VM_STATE[state]
        end

        # return a new (random) MAC address
        def generate_mac_address
          # Don't use Random.new, it causes collisions
          mac = [0x52, 0x54, 0x00, # KVM Vendor prefix
                Random.rand(256),
                Random.rand(256),
                Random.rand(256)]
          mac.map {|x| "%02x" % x}.join(":")
        end

        def read_mac_address
          domain = @conn.lookup_domain_by_uuid(@uuid)
          definition = Util::VmDefinition.new(domain.xml_desc)
          definition.attributes[:mac]
        end

        # Resumes the previously paused virtual machine.
        def resume
          @logger.debug("Resuming paused VM...")
          domain = @conn.lookup_domain_by_uuid(@uuid)
          domain.resume
          true
        end

        def set_name(name)
          @name = name
        end

        def set_gui(vnc_port, vnc_autoport, vnc_password)
          @logger.debug("Enabling GUI")
          update_domain_xml(
            :gui => true,
            :vnc_port => vnc_port,
            :vnc_autoport => vnc_autoport,
            :vnc_password => vnc_password)
        end

        def set_diskbus(disk_bus)
          update_domain_xml(:disk_bus => disk_bus)
        end

        def share_folders(folders)
          update_domain_xml(:p9 => folders)
        end

        def clear_shared_folders
          #stub
        end

        def update_domain_xml(options)
          domain = @conn.lookup_domain_by_uuid(@uuid)
          # Use DOMAIN_XML_SECURE to dump ALL options (including VNC password)
          original_xml = domain.xml_desc(Libvirt::Domain::DOMAIN_XML_SECURE)
          definition = Util::VmDefinition.new(original_xml)
          definition.update(options)
          domain.undefine
          xml = definition.as_xml
          @logger.debug("Updating domain xml\nFrom: #{original_xml}\nTo: #{xml}")
          @conn.define_domain_xml(xml)
        end

        def add_nic(nic)
          domain = @conn.lookup_domain_by_uuid(@uuid)
          # Use DOMAIN_XML_SECURE to dump ALL options (including VNC password)
          original_xml = domain.xml_desc(Libvirt::Domain::DOMAIN_XML_SECURE)
          definition = Util::VmDefinition.new(original_xml)
          definition.add_nic(nic)
          domain.undefine
          xml = definition.as_xml
          @logger.debug("add nic\nFrom #{original_xml} \nTo: #{xml}")
          @conn.define_domain_xml(xml)
        end

        # Starts the virtual machine.
        def start
          domain = @conn.lookup_domain_by_uuid(@uuid)
          domain.create
          true
        end

        # Suspend the virtual machine and saves its states.
        def save
          domain = @conn.lookup_domain_by_uuid(@uuid)
          domain.managed_save
        end

        # Suspend for duration
        # introduced from ruby-libvirt 0.5.0
        def suspend_for_duration(target, duration)
          domain = @conn.lookup_domain_by_uuid(@uuid)
          domain.pmsuspend_for_duration(target, duration)
        end

        # Wakeup the virtual machine
        # introduced from ruby-libvirt 0.5.0
        def wakeup
          domain = @conn.lookup_domain_by_uuid(@uuid)
          domain.pmwakeup
        end

        def can_save?
          domain = @conn.lookup_domain_by_uuid(@uuid)
          definition = Util::VmDefinition.new(domain.xml_desc)
          disk_bus = definition.get(:disk_bus)
          return disk_bus != 'sata'
        end

        # Suspend the virtual machine temporaly
        def suspend
          domain = @conn.lookup_domain_by_uuid(@uuid)
          domain.suspend
        end

        # Export
        def export(xml_path)
          @logger.info("FIXME: export has not tested yet.")
          new_disk = 'disk.img'
          # create new_disk
          domain = @conn.lookup_domain_by_uuid(@uuid)
          definition = Util::VmDefinition.new(domain.xml_desc)
          disk_image = definition.attributes[:disk]
          to_path = File.dirname(xml_path)
          new_path = File.join(to_path, new_disk)
          @logger.info("create disk image #{new_path}")
          run_command("qemu-img convert -c -S 4k -O qcow2 #{disk_image} #{new_path}")
          # write out box.xml
          definition.update(:disk => new_disk,:gui  => false,:uuid => nil)
          File.open(xml_path,'w') do |f|
            f.puts(definition.as_xml)
          end
          # write metadata.json
          json_path=File.join(to_path, 'metadata.json')
          File.open(json_path,'w') do |f|
            f.puts('{"provider": "kvm"}')
          end
        end

        # Executes a command and returns the raw result object.
        def raw(*command, &block)
          int_callback = lambda do
            @interrupted = true
            @logger.info("Interrupted.")
          end

          # Append in the options for subprocess
          command << { :notify => [:stdout, :stderr] }

          Vagrant::Util::Busy.busy(int_callback) do
            Vagrant::Util::Subprocess.execute(@virsh_path, *command, &block)
          end
        end

        def execute_command(command)
          raw(*command)
        end

        # Verifies that the connection is alive
        # introduced from ruby-libvirt 0.5.0
        #
        # This will raise a VagrantError if things are not ready.
        def alive!
          unless @conn.alive?
            raise Vagrant::Errors::KvmNoConnection
          end
        end

        # Verifies that the driver is	 ready and the connection is open
        #
        # This will raise a VagrantError if things are not ready.
        def verify!
          if @conn.closed?
            raise Vagrant::Errors::KvmNoConnection
          end
        end

        # Checks if a VM with the given UUID exists.
        #
        # @return [Boolean]
        def vm_exists?(uuid)
          begin
            @logger.info("Check if VM #{uuid} exists")
            @conn.lookup_domain_by_uuid(uuid)
          rescue Libvirt::RetrieveError
            false
          end
        end

        # Checks which Linux OS variants
        #
        # host_redhat?
        # host_ubuntu?
        # host_debian?
        # host_gentoo?
        # host_arch?
        # @return [Boolean]
        def host_redhat?
          # Check also Korora, CentOS, Fedora,
          #   Oracle Linux < 5.3 and
          #   Red Hat Enterprise Linux and Oracle Linux >= 5.3
          return true if check_os_release?("/etc/redhat-release",
            ["CentOS","Fedora","Korora","Enterprise Linux Enterprise Linux","Red Hat Enterprise Linux"])
          false
        end

        def host_suse?
          check_os_release?("/etc/SuSE-release")
        end

        def host_ubuntu?
          if rel = check_lsb_release?
            return true if rel == "Ubuntu"
          end
          false
        end

        def host_debian?
          check_os_release?("/etc/debian_version")
        end

        def host_gentoo?
          check_os_release?("/etc/gentoo-release")
        end

        def host_arch?
          check_os_release?("/etc/arch-release")
        end

        private

        # Return the qemu version
        #
        # @return [String] of the form "1.2.2"
        def read_version
          # libvirt returns a number like 1002002 for version 1.2.2
          maj = @conn.version / 1000000
          min = (@conn.version - maj*1000000) / 1000
          rel = @conn.version % 1000
          "#{maj}.#{min}.#{rel}"
        end

        # Check contents of release file
        #
        # filename: release file path
        # criteria: ["CentOS","Fedora",...]
        def check_os_release?(filename, criteria=nil)
          return File.exists?(filename) unless criteria

          release_file = Pathname.new(filename)
          if release_file.exist?
            release_file.open("r:ISO-8859-1:UTF-8") do |f|
              contents = f.gets
              criteria.each do |c|
                return true if contents =~ /^#{c}/
              end
            end
          end
          false
        end

        def check_lsb_release?
          return false unless File.exists?("/usr/bin/lsb_release")
          IO.popen('/usr/bin/lsb_release -i') { |o| o.read.chomp.split("\t") }[1]
        end

        def load_kvm_module!
          @logger.info("Check KVM kernel modules")
          kvm = File.readlines('/proc/modules').any? { |line| line =~ /kvm_(intel|amd)/ }
          unless kvm
            case File.read('/proc/cpuinfo')
            when /vmx/
              kvm = true if run_command("sudo /sbin/modprobe kvm-intel")
            when /svm/
              kvm = true if run_command("sudo /sbin/modprobe kvm-amd")
            else
              # looks like virtualization is not supported
            end
          end
          # FIXME: see KVM/ARM project
          raise Errors::VagrantKVMError, "KVM is unavailable" unless kvm
          true
        end

        def connect_libvirt_qemu!
          # Open a connection to the qemu driver
          begin
            @conn = Libvirt::open('qemu:///system')
            @conn.capabilities
          rescue Libvirt::Error => e
            if e.libvirt_code == 5
              # can't connect to hypervisor
              raise Vagrant::Errors::KvmNoConnection
            else
              raise e
            end
          end

          hv_type = @conn.type.to_s
          unless hv_type == "QEMU"
            raise Errors::KvmUnsupportedHypervisor,
              :actual => hv_type, :required => "QEMU"
          end

          version = read_version
          if @conn.version.to_i < 1001000
            raise Errors::KvmInvalidVersion,
              :actual => version, :required => ">= 1.1.0"
          end
        end

      end
    end
  end
end
