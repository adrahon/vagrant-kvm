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

        def initialize(uuid=nil)
          @logger = Log4r::Logger.new("vagrant::provider::kvm::driver")
          @uuid = uuid
          # This should be configurable
          @pool_name = "vagrant"
          @network_name = "vagrant"

          # Open a connection to the qemu driver
          begin
            @conn = Libvirt::open('qemu:///system')
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
              :actual => @version, :required => "< 1.2.0"
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

        def delete
          domain = @conn.lookup_domain_by_uuid(@uuid)
          definition = Util::VmDefinition.new(domain.xml_desc, 'libvirt')
          volume = @pool.lookup_volume_by_path(definition.disk)
          volume.delete
          # XXX remove pool if empty?
          @pool.refresh
          # remove any saved state
          domain.managed_save_remove if domain.has_managed_save?
          domain.undefine
        end

        # Halts the virtual machine
        def halt
          domain = @conn.lookup_domain_by_uuid(@uuid)
          domain.destroy
        end

        # Imports the VM
        #
        # @param [String] xml Path to the libvirt XML file.
        # @param [String] path Destination path for the volume.
        # @param [String] image_type An image type for the volume.
        # @return [String] UUID of the imported VM.
        def import(xml, path, image_type)
          @logger.info("Importing VM")
          # create vm definition from xml
          definition = File.open(xml) { |f|
            Util::VmDefinition.new(f.read) }
          # copy volume to storage pool
          box_disk = definition.disk
          new_disk = File.basename(box_disk, File.extname(box_disk)) + "-" +
            Time.now.to_i.to_s + ".img"
          @logger.info("Copying volume #{box_disk} to #{new_disk}")
          old_path = File.join(File.dirname(xml), box_disk)
          new_path = File.join(path, new_disk)
          # we use qemu-img convert to preserve image size
          system("qemu-img convert -p #{old_path} -O #{image_type} #{new_path}")
          @pool.refresh
          volume = @pool.lookup_volume_by_name(new_disk)
          definition.disk = volume.path
          definition.name = @name
          definition.image_type = image_type
          # create vm
          @logger.info("Creating new VM")
          domain = @conn.define_domain_xml(definition.as_libvirt)
          domain.uuid
        end

        # Imports the VM from an OVF file.
        # XXX should be fusioned with import
        #
        # @param [String] ovf Path to the OVF file.
        # @param [String] path Destination path for the volume.
        # @param [String] image_type An image type for the volume.
        # @return [String] UUID of the imported VM.
        def import_ovf(ovf, path, image_type)
          @logger.info("Importing OVF definition for VM")
          # create vm definition from ovf
          definition = File.open(ovf) { |f|
            Util::VmDefinition.new(f.read, 'ovf') }
          # copy volume to storage pool
          box_disk = definition.disk
          new_disk = File.basename(box_disk, File.extname(box_disk)) + "-" +
            Time.now.to_i.to_s + ".img"
          @logger.info("Converting volume #{box_disk} to #{new_disk}")
          old_path = File.join(File.dirname(ovf), box_disk)
          new_path = File.join(path, new_disk)
          system("qemu-img convert -p #{old_path} -O #{image_type} #{new_path}")
          @pool.refresh
          volume = @pool.lookup_volume_by_name(new_disk)
          definition.disk = volume.path
          definition.name = @name
          definition.image_type = image_type
          # create vm
          @logger.info("Creating new VM")
          domain = @conn.define_domain_xml(definition.as_libvirt)
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
          begin
            # Get the storage pool if it exists
            @pool = @conn.lookup_storage_pool_by_name(@pool_name)
            @logger.info("Init storage pool #{@pool_name}")
          rescue Libvirt::RetrieveError
            # Storage pool doesn't exist so we create it
            # create dir if it doesn't exist
            # if we let libvirt create the dir it is owned by root
            pool_path = base_path.join("storage-pool")
            pool_path.mkpath unless Dir.exists?(pool_path)
            storage_pool_xml = <<-EOF
          <pool type="dir">
            <name>#{@pool_name}</name>
            <target>
              <path>#{pool_path}</path>
            </target>
          </pool>
            EOF
            @pool = @conn.define_storage_pool_xml(storage_pool_xml)
            @pool.build
            @logger.info("Creating storage pool #{@pool_name} in #{pool_path}")
          end
          @pool.create unless @pool.active?
          @pool.refresh
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
          if VM_STATE[state] == :shutoff and domain.has_managed_save?
            return :saved
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
          domain = @conn.lookup_domain_by_uuid(@uuid)
          definition = Util::VmDefinition.new(domain.xml_desc, 'libvirt')
          definition.set_mac(mac)
          domain.undefine
          @conn.define_domain_xml(definition.as_libvirt)
        end

        def set_gui
          domain = @conn.lookup_domain_by_uuid(@uuid)
          definition = Util::VmDefinition.new(domain.xml_desc, 'libvirt')
          definition.set_gui
          domain.undefine
          @conn.define_domain_xml(definition.as_libvirt)
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
