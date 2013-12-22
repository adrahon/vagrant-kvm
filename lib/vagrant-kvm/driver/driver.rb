require 'libvirt'
require 'log4r'

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

        # The QEMU version
        # XXX sufficient or have to check kvm and libvirt versions?
        attr_reader :version

        # KVM support status
        attr_reader :kvm

        def initialize(uuid=nil, conn=nil)
          @logger = Log4r::Logger.new("vagrant::provider::kvm::driver")
          @uuid = uuid
          # This should be configurable
          @pool_name = "vagrant"
          @network_name = "vagrant"

          @logger.info("Check KVM kernel modules")
          @kvm = File.readlines('/proc/modules').any? { |line| line =~ /kvm_(intel|amd)/ }
          unless @kvm
            case File.read('/proc/cpuinfo')
            when /vmx/
              @kvm = true if run_command("sudo /sbin/modprobe kvm-intel")
            when /svm/
              @kvm = true if run_command("sudo /sbin/modprobe kvm-amd")
            else
              # looks like virtualization is not supported
            end
          end
          # FIXME: see KVM/ARM project
          raise Errors::VagrantKVMError, "KVM is unavailable" unless @kvm

          # Open a connection to the qemu driver
          begin
            @conn = conn || Libvirt::open('qemu:///system')
          rescue Libvirt::Error => e
            if e.libvirt_code == 5
              # can't connect to hypervisor
              raise Vagrant::Errors::KvmNoConnection
            else
              raise e
            end
          end

          @version = read_version
          if @version < "1.2.0"
            raise Errors::KvmInvalidVersion,
              :actual => @version, :required => ">= 1.2.0"
          end

          # Get storage pool if it exists
          begin
            @pool = @conn.lookup_storage_pool_by_name(@pool_name)
            @logger.info("Init storage pool #{@pool_name}")
          rescue Libvirt::RetrieveError
            # storage pool doesn't exist yet
          end

          if @uuid
            # Verify the VM exists, and if it doesn't, then don't worry
            # about it (mark the UUID as nil)
            raise VMNotFound if !vm_exists?(@uuid)
          end
        end

        # create empty volume in storage pool
        def create_volume(disk_name, capacity, path, image_type, box_pool, box_path, backing=false)
          msg = "Creating volume #{disk_name}"
          msg += " backed by volume #{box_path}" if backing
          @logger.info(msg)
          storage_vol_xml = <<-EOF
          <volume>
            <name>#{disk_name}</name>
            <allocation>0</allocation>
            <capacity unit="#{capacity[:unit]}">#{capacity[:size]}</capacity>
            <target>
              <path>#{path}</path>
              <format type='#{image_type}'/>
            </target>
          EOF
          if backing
            storage_vol_xml += <<-EOF
            <backingStore>
              <path>#{box_path}</path>
              <format type='#{image_type}'/>
            </backingStore>
            EOF
          end
          storage_vol_xml += <<-EOF
          </volume>
          EOF

          @logger.debug "Creating volume with XML:\n#{storage_vol_xml}"
          if backing
            vol = @pool.create_volume_xml(storage_vol_xml)
          else
            pool = @conn.lookup_storage_pool_by_name(box_pool)
            clonevol = pool.lookup_volume_by_path(box_path)
            # create_volume_xml_from() can convert disk image type automatically.
            vol = @pool.create_volume_xml_from(storage_vol_xml, clonevol)
          end
          @pool.refresh
        end

        def delete
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
        def import(definition, volume_name, args={})
          @logger.info("Importing VM #{@name}")
          # create vm definition from xml
          definition = File.open(definition) { |f| Util::VmDefinition.new(f.read) }
          volume = @pool.lookup_volume_by_name(volume_name)
          args = {
            :image_type => "qcow2",
            :qemu_bin => "/usr/bin/qemu",
            :disk => volume.path,
            :name => @name
          }.merge(args)
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
          begin
            # Get the network if it exists
            @network = @conn.lookup_network_by_name(@network_name)
            definition = Util::NetworkDefinition.new(@network_name,
                                                     @network.xml_desc)
            @network.destroy if @network.active?
            @network.undefine
          rescue Libvirt::RetrieveError
            # Network doesn't exist, create with defaults
            definition = Util::NetworkDefinition.new(@network_name)
          end
          definition.configure(config)
          @network = @conn.define_network_xml(definition.as_xml)
          @logger.info("Creating network #{@network_name}")
          @network.create
        end

        # Initialize or create storage pool
        def init_storage(base_path)
          # Storage pool doesn't exist so we create it
          # create dir if it doesn't exist
          # if we let libvirt create the dir it is owned by root
          pool_path = base_path.join("storage-pool")
          pool_path.mkpath unless Dir.exists?(pool_path)
          @pool = init_storage_directory(pool_path, @pool_name)
        end

        def init_storage_directory(pool_path, pool_name)
          begin
            # Get the storage pool if it exists
            pool = @conn.lookup_storage_pool_by_name(pool_name)
            @logger.info("Init storage pool #{pool_name}")
          rescue Libvirt::RetrieveError
            owner = Process.uid
            group = Process.gid
            storage_pool_xml = <<-EOF
              <pool type="dir">
              <name>#{pool_name}</name>
              <target>
                <path>#{pool_path}</path>
                <permissions>
                 <owner>#{owner}</owner>
                 <group>#{group}</group>
                 <mode>774</mode>
                </permissions>
              </target>
              </pool>
            EOF
            pool = @conn.define_storage_pool_xml(storage_pool_xml)
            pool.build
            @logger.info("Creating storage pool #{pool_name} in #{pool_path}")
          end
          pool.create unless pool.active?
          pool.refresh
          pool
        end

        def free_storage_pool(pool_name)
          begin
            pool = @conn.lookup_storage_pool_by_name(pool_name)
            pool.destroy
            pool.free
          rescue Libvirt::RetrieveError
            @logger.info("fail to free storage pool #{pool_name}")
          end
        end

        # Returns a list of network interfaces of the VM.
        #
        # @return [Hash]
        def read_network_interfaces
          domain = @conn.lookup_domain_by_uuid(@uuid)
          Util::VmDefinition.list_interfaces(domain.xml_desc)
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

        def set_mac_address(mac)
          update_domain_xml(:mac => mac)
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

        # Starts the virtual machine.
        def start
          domain = @conn.lookup_domain_by_uuid(@uuid)
          domain.create
          true
        end

        # Suspend the virtual machine and saves its states.
        def suspend
          domain = @conn.lookup_domain_by_uuid(@uuid)
          domain.managed_save
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
          run_command("qemu-img convert -S 16k -O qcow2 #{disk_image} #{new_path}")
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

        # Verifies that the driver is ready and the connection is open
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
      end
    end
  end
end
