module VagrantPlugins
  module ProviderKvm
    module Util
      module DefinitionAttributes
        module InstanceMethods
          def attributes
            @attributes ||= {}
          end

          def attributes=(attrs)
            @attributes = attrs
          end

          def get(key)
            attributes[key]
          end

          def set(key, val)
            attributes[key] = val
          end

          def update(args={})
            attributes.merge!(args)
          end

          def ==(other)
            self.attributes == other.attributes
          end
        end

        def self.included(receiver)
          receiver.send :include, InstanceMethods
        end
      end
    end
  end
end
