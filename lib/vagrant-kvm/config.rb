module VagrantPlugins
  module ProviderKvm
    class Config < Vagrant.plugin("2", :config)
      # An array of customizations to make on the VM prior to booting it.
      #
      # @return [Array]
      attr_reader :customizations

      # If set to `true`, then KVM/Qemu will be launched with a VNC console.
      #
      # @return [Boolean]
      attr_accessor :gui

      # This should be set to the name of the VM
      #
      # @return [String]
      attr_accessor :name

      # The defined network adapters.
      #
      # @return [Hash]
      attr_reader :network_adapters

      # The VM image format
      #
      # @return [String]
      attr_accessor :image_type

      # VM image mode(clone or COW with backing file)
      #
      # @return [Boolean]
      attr_reader :image_backing

      # VM image mode(clone or COW with backing file)
      #
      # @return [Boolean]
      attr_accessor :image_mode

      # path of qemu binary
      #
      # @return [String]
      attr_accessor :qemu_bin

      # cpu model
      #
      # @return [String]: x86_64/i386
      attr_accessor :cpu_model

      # memory size in bytes
      # default: defined in box
      #
      # @return [String]
      attr_accessor :memory_size

      # core number of cpu
      # default: defined in box
      #
      # @return [String]
      attr_accessor :core_number
      attr_accessor :vnc_port
      attr_accessor :vnc_autoport
      attr_accessor :vnc_password
      attr_accessor :machine_type
      attr_accessor :network_model
      attr_accessor :video_model

      def initialize
        @name             = UNSET_VALUE
        @gui              = UNSET_VALUE
        @image_type       = UNSET_VALUE
        @image_mode       = UNSET_VALUE
        @qemu_bin         = UNSET_VALUE
        @cpu_model        = UNSET_VALUE
        @memory_size      = UNSET_VALUE
        @core_number      = UNSET_VALUE
        @vnc_port         = UNSET_VALUE
        @vnc_autoport     = UNSET_VALUE
        @vnc_password     = UNSET_VALUE
        @machine_type     = UNSET_VALUE
        @network_model    = UNSET_VALUE
        @video_model      = UNSET_VALUE
      end

      # This is the hook that is called to finalize the object before it
      # is put into use.
      def finalize!
        # The default name is just nothing, and we default it
        @name = nil if @name == UNSET_VALUE
        # Default is to not show a GUI
        @gui = false if @gui == UNSET_VALUE
        # Default image type is a sparsed raw
        @image_type = 'qcow2' if @image_type == UNSET_VALUE
        case @image_mode
        when UNSET_VALUE
          @image_backing = true
        when 'clone'
          @image_backing = false
        when 'cow'
          @image_backing = true
        else
          @image_backing = true
        end
        # Search qemu binary with the default behavior
        @qemu_bin = nil if @qemu_bin == UNSET_VALUE
        # Default cpu model is x86_64, acceptable only x86_64/i686
        @cpu_model = 'x86_64' if @cpu_model == UNSET_VALUE
        @cpu_model = 'x86_64' unless @cpu_model =~ /^(i686|x86_64)$/
        # Process memory size directive
        # accept the case
        # integer recgnized as KiB
        # <num>KiB/KB/kb/MiB/MB/mb/GiB/GB/gb
        #
        case @memory_size
        when /^([0-9][0-9]*)(KiB|kib)$/
          @memory_size = ("#{$1}".to_i * 1024).to_s
        when /^([0-9][0-9]*)(KB|kb)$/
          @memory_size = ("#{$1}".to_i * 1000).to_s
        when /^([0-9][0-9]*)(m||MiB|mib|)$/
          @memory_size = ("#{$1}".to_i * 1048576).to_s
        when /^([0-9][0-9]*)(MB|mb|)$/
          @memory_size = ("#{$1}".to_i * 1000000).to_s
        when /^([0-9][0-9]*)(g||GiB|gib)$/
          @memory_size = ("#{$1}".to_i * 1073741824).to_s
        when /^([0-9][0-9]*)(GB|gb|)$/
          @memory_size = ("#{$1}".to_i * 1000000000).to_s
        when /^([0-9][0-9]*)$/
          @memory_size = ("#{$1}".to_i * 1024).to_s
        when UNSET_VALUE
          @memory_size = nil
        else
          @memory_size = nil
        end
        # Default core number is 1
        @core_number = 1 if @core_number == UNSET_VALUE

        @vnc_autoport = false if @vnc_autoport == UNSET_VALUE
        @vnc_password = nil if @vnc_password == UNSET_VALUE
        @vnc_port = -1 if @vnc_port == UNSET_VALUE
        @machine_type = "pc-1.2" if @machine_type == UNSET_VALUE
        @network_model = "virtio" if @network_model == UNSET_VALUE
        @video_model = "cirrus" if @video_model == UNSET_VALUE
      end
    end
  end
end
