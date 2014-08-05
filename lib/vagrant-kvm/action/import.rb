require 'etc'

module VagrantPlugins
  module ProviderKvm
    module Action
      class Import
        include Util
        include Util::Commands

        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new("vagrant::kvm::action::import")
        end

        def call(env)
          @env = env
          @env[:ui].info I18n.t("vagrant.actions.vm.import.importing",
                               :name => env[:machine].box.name)

          provider_config = @env[:machine].provider_config

          # Ignore unsupported image types
          args={:image_type => provider_config.image_type}
          args[:image_type] = 'qcow2' unless args[:image_type] == 'raw'
          # Add memory attribute when specified
          if provider_config.memory_size
            args[:memory] = provider_config.memory_size
          end

          # import arguments
          args = {
            :image_backing => provider_config.image_backing,
            :qemu_bin      => provider_config.qemu_bin,
            :cpus          => provider_config.core_number,
            :cpu_model     => provider_config.cpu_model,
            :machine_type  => provider_config.machine_type,
            :network_model => provider_config.network_model,
            :video_model   => provider_config.video_model,
            :virtio_rng    => provider_config.virtio_rng
          }.merge(args)

          args[:disk_bus]   = provider_config.disk_bus if provider_config.disk_bus

          # Permission/Security Model detection
          driver = @env[:machine].provider.driver
          # defaults
          args[:userid] = Process.uid.to_s
          args[:groupid] = Process.gid.to_s
          args[:dirmode] = '0775'
          args[:filemode] = '0664'
          args[:label] = 'virt_image_t'
          args[:secmodel] = nil
          # Optional security label
          if provider_config.seclabel == 'on'
            # OS specific
            if driver.host_redhat?
              # on Redhat/Fedora, permission is controlled
              # with only SELinux
              args[:secmodel] = 'selinux'
              args[:dirmode]  = '0777'
              args[:filemode] = '0666'
            elsif driver.host_arch?
              # XXX: should be configurable
              args[:secmodel] = 'dac'
            elsif driver.host_ubuntu?
              args[:secmodel] = 'apparmor'
              args[:groupid] = Etc.getgrnam('kvm').gid.to_s
            elsif driver.host_debian?
              # XXX: should be configurable
              args[:secmodel] = 'dac'
              args[:groupid] = Etc.getgrnam('kvm').gid.to_s
            end
          end

          # Import the virtual machine

          # Get storage pool directory
          storage_path = @env[:machine].provider.driver.storage_pool_path
          box_file = @env[:machine].box.directory.join("box.xml").to_s
          raise Errors::KvmBadBoxFormat unless File.file?(box_file)

          # check pool migration neccesary?
          if @env[:machine].provider.driver.pool_migrate
            @env[:ui].output I18n.t("vagrant_kvm.kvm_spool_problem_inform")
          end

          # repair directories permission
          home_path = File.expand_path("../../", @env[:tmp_path])
          boxes_path = File.expand_path("../boxes/", @env[:tmp_path])
          repair_permissions!(home_path, boxes_path)

          # import box volume
          volume_name = import_volume(storage_path, box_file, args)

          # import the box to a new vm
          env[:machine].id = @env[:machine].provider.driver.import(box_file, volume_name, args)

          # If we got interrupted, then the import could have been
          # interrupted and its not a big deal. Just return out.
          return if @env[:interrupted]

          # Flag as erroneous and return if import failed
          raise Vagrant::Errors::VMImportFailure if !@env[:machine].id

          # Import completed successfully. Continue the chain
          @app.call(env)
        end

        def import_volume(storage_path, box_file, args)
          @logger.debug "Importing volume. Storage path: #{storage_path} " + 
            "Image Type: #{args[:image_type]}"

          box_disk = @env[:machine].provider.driver.find_box_disk(box_file)
          new_disk = File.basename(box_disk, File.extname(box_disk)) + "-" +
            Time.now.to_i.to_s + ".img"
          old_path = File.join(File.dirname(box_file), box_disk)
          new_path = File.join(storage_path, new_disk)

          # for backward compatibility, we handle both raw and qcow2 box format
          box = Util::DiskInfo.new(old_path)
          if box.type == 'raw' || args[:image_type] == 'raw'
            args[:image_baking] = false
            @logger.info "Disable disk image with box image as backing file"
          end

          if args[:image_type] == 'qcow2' || args[:image_type] == 'raw'
            # create volume
            box_name = @env[:machine].config.vm.box
            driver = @env[:machine].provider.driver
            userid = Process.uid.to_s
            begin
              # vagrant 1.5+
              box_version = @env[machine].config.vm.box_version
              pool_name = 'vagrant_' + userid + '_' + box_name + '_' + box_version.to_s
            rescue
              # before varant 1.5
              pool_name = 'vagrant_' + userid + '_' + box_name
            end
            driver.init_storage_pool(pool_name, File.dirname(old_path), args[:dirmode])
            driver.create_volume(
                :disk_name => new_disk,
                :capacity => box.capacity,
                :path => new_path,
                :image_type => args[:image_type],
                :box_pool => pool_name,
                :box_path => old_path,
                :backing => args[:image_backing],
                :owner => args[:userid],
                :group => args[:groupid],
                :mode => args[:filemode],
                :label => args[:label])
            driver.free_storage_pool(pool_name)
          else
            @logger.info "Image type #{args[:image_type]} is not supported"
          end
          # TODO cleanup if interrupted
          new_disk
        end

        # Repairs $HOME an $HOME/.vagrangt.d/boxes permissions.
        #
        # work around for
        # https://github.com/adrahon/vagrant-kvm/issues/193
        # https://github.com/adrahon/vagrant-kvm/issues/163
        # https://github.com/adrahon/vagrant-kvm/issues/130
        #
        def repair_permissions!(home_path, boxes_path)
          # check pathes
          [home_path, boxes_path].each do |d|
            s = File::Stat.new(d)
            @logger.debug("#{d} permission: #{s.mode.to_s(8)}")
            if (s.mode & 1 == 0)
              @env[:ui].info I18n.t("vagrant_kvm.repair_permission",:directory => d,
                :old_mode => sprintf("%o",s.mode), :new_mode => sprintf("%o", s.mode|1))
              File.chmod(s.mode | 1, d)
            end
          end
        end

        def recover(env)
          if env[:machine].provider.state.id != :not_created
            return if env["vagrant.error"].is_a?(Vagrant::Errors::VagrantError)

            # Interrupted, destroy the VM. We note that we don't want to
            # validate the configuration here, and we don't want to confirm
            # we want to destroy.
            destroy_env = env.clone
            destroy_env[:config_validate] = false
            destroy_env[:force_confirm_destroy] = true
            env[:action_runner].run(Action.action_destroy, destroy_env)
          end
        end
      end
    end
  end
end
