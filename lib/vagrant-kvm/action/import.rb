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

          # import arguments
          args = {
            :image_backing => provider_config.image_backing,
            :qemu_bin      => provider_config.qemu_bin,
            :cpus          => provider_config.core_number,
            :memory_size   => provider_config.memory_size,
            :cpu_model     => provider_config.cpu_model,
            :machine_type  => provider_config.machine_type,
            :network_model => provider_config.network_model,
            :video_model   => provider_config.video_model
          }.merge(args)

          # Import the virtual machine
          storage_path = File.join(@env[:tmp_path],"/storage-pool")
          box_file = @env[:machine].box.directory.join("box.xml").to_s
          raise Errors::KvmBadBoxFormat unless File.file?(box_file)

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
            pool_name = 'vagrant_' + Process.uid.to_s + '_' + box_name
            driver.init_storage_directory(File.dirname(old_path), pool_name)
            driver.create_volume(new_disk, box.capacity, new_path, args[:image_type], pool_name, old_path, args[:image_backing])
            driver.free_storage_pool(pool_name)
          else
            @logger.info "Image type #{args[:image_type]} is not supported"
          end
          # TODO cleanup if interupted
          new_disk
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
