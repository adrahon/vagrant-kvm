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
          pool_path = File.join(env[:tmp_path], "/storage-pool")
          env[:machine].provider.driver.init_storage_pool(pool, pool_path)
          env[:machine].provider.driver.activate_storage_pool(pool)

          @app.call(env)
        end
      end
    end
  end
end
