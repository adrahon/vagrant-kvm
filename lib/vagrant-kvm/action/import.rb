module VagrantPlugins
  module ProviderKvm
    module Action
      class Import
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:ui].info I18n.t("vagrant.actions.vm.import.importing",
                               :name => env[:machine].box.name)

          # Ignore unsupported image types
          image_type = env[:machine].provider_config.image_type
          image_type = 'raw' unless image_type == 'qcow2'

          qemu_bin = env[:machine].provider_config.qemu_bin

          # Import the virtual machine (ovf or libvirt)
          # if a libvirt XML definition is present we use it
          # otherwise we convert the OVF
          storage_path = File.join(env[:tmp_path],"/storage-pool")
          box_file = env[:machine].box.directory.join("box.xml").to_s
          if File.file?(box_file)
            env[:machine].id = env[:machine].provider.driver.import(
                        box_file, storage_path, image_type, qemu_bin)
          else
            box_file = env[:machine].box.directory.join("box.ovf").to_s
            env[:machine].id = env[:machine].provider.driver.import_ovf(
                        box_file, storage_path, image_type, qemu_bin)
          end

          # If we got interrupted, then the import could have been
          # interrupted and its not a big deal. Just return out.
          return if env[:interrupted]

          # Flag as erroneous and return if import failed
          raise Vagrant::Errors::VMImportFailure if !env[:machine].id

          # Import completed successfully. Continue the chain
          @app.call(env)
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
