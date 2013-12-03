module VagrantPlugins
  module ProviderKvm
    module Util
      module Commands
        def run_command(cmd)
          unless res = system(cmd)
            raise Errors::KvmFailedCommand, "System command #{cmd} returned with error code #{res}"
          end
          res
        end
      end
    end
  end
end

