module VagrantPlugins
  module ProviderKvm
    module Action
      class Import
        include Util::Commands

        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new("vagrant::kvm::action::import")
        end

        def call(env)
          env[:ui].info I18n.t("vagrant.actions.vm.import.importing",
                               :name => env[:machine].box.name)

          provider_config = env[:machine].provider_config

          # Ignore unsupported image types
          image_type = env[:machine].provider_config.image_type
          image_type = 'qcow2' unless image_type == 'raw'

          qemu_bin = provider_config.qemu_bin

          cpus = provider_config.core_number
          memory_size = provider_config.memory_size
          cpu_model = provider_config.cpu_model
          machine_type = provider_config.machine_type

          # Import the virtual machine (ovf or libvirt) if a libvirt XML
          # definition is present we use it otherwise we convert the OVF
          storage_path = File.join(env[:tmp_path],"/storage-pool")
          box_file = env[:machine].box.directory.join("box.xml").to_s
          if File.file?(box_file)
            box_type = "libvirt"
          else
            box_file = env[:machine].box.directory.join("box.ovf").to_s
            box_type = "ovf"
          end
          raise Errors::KvmBadBoxFormat unless File.file?(box_file)

          # import box volume
          volume_name = import_volume(storage_path, image_type, box_file, box_type, env)

          # import the box to a new vm
          env[:machine].id = env[:machine].provider.driver.import(
            box_file, box_type, volume_name, image_type, qemu_bin, cpus, memory_size, cpu_model, machine_type)

          # If we got interrupted, then the import could have been
          # interrupted and its not a big deal. Just return out.
          return if env[:interrupted]

          # Flag as erroneous and return if import failed
          raise Vagrant::Errors::VMImportFailure if !env[:machine].id

          # Import completed successfully. Continue the chain
          @app.call(env)
        end

        def import_volume(storage_path, image_type, box_file, box_type, env)
          box_disk = env[:machine].provider.driver.find_box_disk(box_file, box_type)
          new_disk = File.basename(box_disk, File.extname(box_disk)) + "-" +
            Time.now.to_i.to_s + ".img"
          old_path = File.join(File.dirname(box_file), box_disk)
          new_path = File.join(storage_path, new_disk)

          # if ovf convert box volume
          if box_type == 'ovf'
            tmp_disk = File.basename(box_disk, File.extname(box_disk)) + ".img"
            tmp_path = File.join(File.dirname(box_file), tmp_disk)
            unless File.file?(tmp_path)
              options = "-c -S 16k" if image_type == 'qcow2' # XXX is -S 16k necessary?
              #env[:logger].info("Converting box image to #{image_type} volume #{tmp_disk}")
              # no access to log?
              if system("qemu-img convert -p #{old_path} #{options} -O #{image_type} #{tmp_path}")
                File.unlink(old_path)
              else
                raise Errors::KvmFailImageConversion
              end
            end
            old_path = tmp_path
          end

          capacity = volume_size(old_path)
          if image_type == 'qcow2'
            # create volume with box disk as backing volume
            env[:machine].provider.driver.create_volume(new_disk, capacity, new_path, image_type, old_path)
          elsif image_type == 'raw'
            # create volume then upload box disk content
            env[:machine].provider.driver.create_volume(new_disk, capacity, new_path, image_type)
            # Upload box image content (taken from vagrant-libvirt)
            box_image_size = Integer(capacity[:size])
            result = env[:machine].provider.driver.upload_image(
              old_path, new_disk, box_image_size) do |progress|
                env[:ui].clear_line
                env[:ui].report_progress(progress, box_image_size, false)
              end
              env[:ui].clear_line
          end
          # TODO cleanup if interupted
          new_disk
        end

        # returns volume virtual capacity
        def volume_size(vol_path)
          # default values
          vol_vsize = {:size => 10, :unit => 'G'}
          begin
            vsize_regex = %r{virtual size:\s+(?<size>\d+(\.\d+)?)(?<unit>.)\s+\((?<bytesize>\d+)\sbytes\)}
            diskinfo = %x[qemu-img info #{vol_path}]
            diskinfo.each_line do |line|
              result = line.match(vsize_regex)
              if result
                # always take the size in bytes to avoid conversion
                vol_vsize = {:size => result[:bytesize], :unit => "B"}
                break
              end
            end
          rescue Errors::KvmFailedCommand =>e
            @logger.error 'Failed to find volume size. Using defaults.'
            @logger.error e
          end
          vol_vsize
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
