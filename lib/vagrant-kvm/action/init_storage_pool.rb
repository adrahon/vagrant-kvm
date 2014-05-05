module VagrantPlugins
  module ProviderKvm
    module Action
      # Initialize storage pool.
      class InitStoragePool
        def initialize(app, env)
          @app = app
        end

        def call(env)
          # Create the storage pool in tmp_path if it doesn't exist
          pool = env[:machine].provider_config.storage_pool
          unless Driver::Driver.new.storage_pool_exists?(pool)
            pool_path = File.join(env[:tmp_path], "/storage-pool")
            Driver::Driver.new.create_storage_pool(pool, pool_path)
          end
          # Create one in tmp_path if there's none
          #userid = Process.uid.to_s
          #groupid = Process.gid.to_s
          #Driver::Driver.new.init_storage(env[:tmp_path], userid, groupid)

          @app.call(env)
        end
      end
    end
  end
end
