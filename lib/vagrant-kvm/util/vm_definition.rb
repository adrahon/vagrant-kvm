# Utility class to translate ovf definition to libvirt XML
# and manage XML formatting for libvirt interaction
# Not a full OVF converter, only the minimal needed definition
require "nokogiri"

module VagrantPlugins
  module ProviderKvm
    module Util
      class VmDefinition
        # Attributes of the VM
        attr_accessor :name
        attr_reader :cpus
        attr_accessor :disk
        attr_reader :mac
        attr_reader :arch
        attr_reader :network

        def self.list_interfaces(definition)
          nics = {}
          ifcount = 0
          doc = Nokogiri::XML(definition)
          # look for user mode interfaces
          doc.css("devices interface[type='user']").each do |item|
            ifcount += 1
            adapter = ifcount
            nics[adapter] ||= {}
            nics[adapter][:type] = :user
          end
          # look for interfaces on virtual network
          doc.css("devices interface[type='netwok']").each do |item|
            ifcount += 1
            adapter = ifcount
            nics[adapter] ||= {}
            nics[adapter][:network] = item.at_css("source")["network"]
            nics[adapter][:type] = :network
          end
          nics
        end

        def initialize(definition, source_type='libvirt')
          @uuid = nil
          @network = 'default'
          if source_type == 'ovf'
            create_from_ovf(definition)
          else
            create_from_libvirt(definition)
          end
        end

        def create_from_ovf(definition)
          doc = Nokogiri::XML(definition)
          # we don't need no namespace
          doc.remove_namespaces!
          @name = doc.at_css("VirtualSystemIdentifier").content
          devices = doc.css("VirtualHardwareSection Item")
          for device in devices
            case device.at_css("ResourceType").content
              # CPU
            when "3"
              @cpus = device.at_css("VirtualQuantity").content
              # Memory
            when "4"
              @memory = size_in_bytes(device.at_css("VirtualQuantity").content,
                                      device.at_css("AllocationUnits").content)
            end
          end

          # disk volume
          diskref = doc.at_css("DiskSection Disk")["fileRef"]
          @disk = doc.at_css("References File[id='#{diskref}']")["href"]

          # mac address
          # XXX we use only the first nic
          @mac = format_mac(doc.at_css("Machine Hardware Adapter[enabled='true']")['MACAddress'])

          # the architecture is not defined in the ovf file
          # we try to guess from OSType
          # see https://www.virtualbox.org/browser/vbox/trunk/src/VBox/Main/include/ovfreader.h
          @arch = doc.at_css("VirtualSystemIdentifier").
            content[-2..-1] == '64' ? "x86_64" : "i686"
        end

        def create_from_libvirt(definition)
          doc = Nokogiri::XML(definition)
          @name = doc.at_css("domain name").content
          @uuid = doc.at_css("domain uuid").content if doc.at_css("domain uuid")
          memory_unit = doc.at_css("domain memory")["unit"]
          @memory = size_in_bytes(doc.at_css("domain memory").content,
                                  memory_unit)
          @cpus = doc.at_css("domain vcpu").content
          @arch = doc.at_css("domain os type")["arch"]
          @disk = doc.at_css("devices disk source")["file"]
          @mac = doc.at_css("devices interface mac")["address"]
          @network = doc.at_css("devices interface source")["network"]
        end

        def as_libvirt
          # RedHat and Debian-based systems have different executable names
          # depending on version/architectures
          qemu_bin = [ '/usr/bin/qemu-kvm', '/usr/bin/kvm' ]
          qemu_bin << '/usr/bin/qemu-system-x86_64' if @arch.match(/64$/)
          qemu_bin << '/usr/bin/qemu-system-i386'   if @arch.match(/^i.86$/)

          xml = KvmTemplateRenderer.render("libvirt_domain", {
            :name => @name,
            :uuid => @uuid,
            :memory => size_from_bytes(@memory, "KiB"),
            :cpus => @cpus,
            :arch => @arch,
            :disk => @disk,
            :mac => format_mac(@mac),
            :network => @network,
            :qemu_bin => qemu_bin.detect { |binary| File.exists? binary }
          })
          xml
        end

        def get_memory(unit="bytes")
          size_from_bytes(@memory, unit)
        end

        def set_mac(mac)
          @mac = format_mac(mac)
        end

        # Takes a quantity and a unit
        # returns quantity in bytes
        # mib = true to use mebibytes, etc
        # defaults to false because ovf MB != megabytes
        def size_in_bytes(qty, unit, mib=false)
          qty = qty.to_i
          unit = unit.downcase
          if !mib
            case unit
            when "kb", "kilobytes"
              unit = "kib"
            when "mb", "megabytes"
              unit = "mib"
            when "gb", "gigabytes"
              unit = "gib"
            end
          end
          case unit
          when "b", "bytes"
            qty.to_s
          when "kb", "kilobytes"
            (qty * 1000).to_s
          when "kib", "kibibytes"
            (qty * 1024).to_s
          when "mb", "megabytes"
            (qty * 1000000).to_s
          when "m", "mib", "mebibytes"
            (qty * 1048576).to_s
          when "gb", "gigabytes"
            (qty * 1000000000).to_s
          when "g", "gib", "gibibytes"
            (qty * 1073741824).to_s
          else
            raise ArgumentError, "Unknown unit #{unit}"
          end
        end

        # Takes a qty and a unit
        # returns byte quantity in that unit
        def size_from_bytes(qty, unit)
          qty = qty.to_i
          case unit.downcase
          when "b", "bytes"
            qty.to_s
          when "kb", "kilobytes"
            (qty / 1000).to_s
          when "kib", "kibibytes"
            (qty / 1024).to_s
          when "mb", "megabytes"
            (qty / 1000000).to_s
          when "m", "mib", "mebibytes"
            (qty / 1048576).to_s
          when "gb", "gigabytes"
            (qty / 1000000000).to_s
          when "g", "gib", "gibibytes"
            (qty / 1073741824).to_s
          else
            raise ArgumentError, "Unknown unit #{unit}"
          end
        end

        def format_mac(mac)
          if mac.length == 12
            mac = mac[0..1] + ":" + mac[2..3] + ":" +
              mac[4..5] + ":" + mac[6..7] + ":" +
              mac[8..9] + ":" + mac[10..11]
          end
          mac
        end

      end
    end
  end
end
