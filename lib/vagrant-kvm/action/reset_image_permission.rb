module VagrantPlugins
  module ProviderKvm
    module Action
      class ResetImagePermission
        def initialize(app, env)
          @app = app
        end

        def call(env)

          #current_state = env[:machine].state.id
          #if current_state == :shutoff
            userid = Process.uid.to_s
            groupid = Process.gid.to_s
            env[:machine].provider.driver.reset_volume_permission(userid, groupid)
          #end

          @app.call(env)
        end
      end
    end
  end
end
