module VagrantPlugins
  module ProviderKvm
    module Action
      class PackageVagrantfile

        include ProviderKvm::Util

        def initialize(app, env)
          @app = app
        end

        def call(env)
          @env = env
          create_vagrantfile
          @app.call(env)
        end

        # This method creates the auto-generated Vagrantfile at the root of the
        # box. This Vagrantfile contains the MAC address so that the user doesn't
        # have to worry about it.
        def create_vagrantfile
          File.open(File.join(@env["export.temp_dir"], "Vagrantfile"), "w") do |f|
            f.write(KvmTemplateRenderer.render("package_Vagrantfile", {
              :base_mac => @env[:machine].provider.driver.read_mac_address
            }))
          end
        end
      end
    end
  end
end
