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
          userid = Process.uid.to_s
          groupid = Process.gid.to_s
          Driver::Driver.new.init_storage(env[:tmp_path], userid, groupid)

          @app.call(env)
        end
      end
    end
  end
end
