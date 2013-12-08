module VagrantPlugins
  module ProviderKvm
    module Util
      class DiskInfo
        include Errors

        attr_reader :backing, :capacity, :cluster, :size, :type

        def initialize(vol_path)
          logger = Log4r::Logger.new("vagrant::kvm::util::disk_info")
          # default values
          @capacity = {:size => 10, :unit => 'G'}
          @backing = nil
          @cluster = nil
          begin
            diskinfo = %x[qemu-img info #{vol_path}]
            diskinfo.each_line do |line|
              case line
              when /^file format:/
                result = line.match(%r{file format:\s+(?<format>(\w+))})
                @type = result[:format]
              when /virtual size:/
                result = line.match(%r{virtual size:\s+(?<size>\d+(\.\d+)?)(?<unit>.)\s+\((?<bytesize>\d+)\sbytes\)})
                # always take the size in bytes to avoid conversion
                @capacity = {:size => result[:bytesize], :unit => "B"}
              when /^disk size:/
                result = line.match(%r{disk size:\s+(?<size>\d+(\.\d+)?)(?<unit>.)})
                @size = {:size => result[:size], :unit => result[:unit]}
              when /^backing file:/
                result = line.match(%r{backing file:\s+(?<file>(\S+))})
                @backing = result[:file]
              when /^cluster[_ ]size:/
                result = line.match(%r{cluster[_ ]size:\s+(?<size>(\d+))})
                @cluster = result[:size]
              end
            end
          rescue Errors::KvmFailedCommand => e
            logger.error 'Failed to find volume size. Using defaults.'
            logger.error e
          end
        end

        # TBD backing chain 'qemu-img info --backing-chain'

      end
    end
  end
end
