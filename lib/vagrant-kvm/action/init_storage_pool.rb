module VagrantPlugins
  module ProviderKvm
    module Action
      # Initialize storage pool.
      class InitStoragePool
        def initialize(app, env)
          @app = app
        end

        def call(env)
          # Create a storage pool in tmp_path if it doesn't exist
          Driver::Driver.new.init_storage(env[:tmp_path])

          @app.call(env)
        end
      end
    end
  end
end
