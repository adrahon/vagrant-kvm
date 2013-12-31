module VagrantPlugins
  module ProviderKvm
    module Util
      module Commands
        def run_command(cmd)
          unless res = system(cmd)
            raise Errors::KvmFailedCommand, cmd: cmd, res: res
          end
          res
        end
      end
    end
  end
end

