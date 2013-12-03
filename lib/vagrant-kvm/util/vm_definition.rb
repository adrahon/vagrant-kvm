# Utility class to translate ovf definition to libvirt XML
# and manage XML formatting for libvirt interaction
# Not a full OVF converter, only the minimal needed definition
require "rexml/document"

module VagrantPlugins
  module ProviderKvm
    module Util
      class VmDefinition
        include Errors

        # Attributes of the VM
        attr_accessor :name, :image_type, :qemu_bin, :disk, :vnc_port, :vnc_autoport, 
          :vnc_password, :gui, :cpus, :arch, :memory, :machine_type

        attr_reader :mac, :arch, :network

        def self.list_interfaces(definition)
          nics = {}
          ifcount = 0
          doc = REXML::Document new definition
          # look for user mode interfaces
          doc.elements.each("//devices/interface[@type='user']") do |item|
            ifcount += 1
            adapter = ifcount
            nics[adapter] ||= {}
            nics[adapter][:type] = :user
          end
          # look for interfaces on virtual network
          doc.elements.each("//devices/interface[@type='network']") do |item|
            ifcount += 1
            adapter = ifcount
            nics[adapter] ||= {}
            nics[adapter][:network] = item.elements["source"].attributes["network"]
            nics[adapter][:type] = :network
          end
          nics
        end

        def initialize(definition, source_type='libvirt')
          @uuid = nil
          @gui = nil
          @vnc_autoport = false 
          @vnc_password = nil
          @network = 'default'
          if source_type == 'ovf'
            create_from_ovf(definition)
          else
            create_from_libvirt(definition)
          end
        end

        def create_from_ovf(definition)
          doc = REXML::Document.new definition
          # we don't need no namespace
          #doc.remove_namespaces!
          @name = doc.elements["//VirtualSystemIdentifier"].text if doc.elements["//VirtualSystemIdentifier"]
          doc.elements.each("//VirtualHardwareSection/Item") do |device|
            case device.elements["rasd:ResourceType"].text
              # CPU
            when "3"
              @cpus = device.elements["rasd:VirtualQuantity"].text
              # Memory
            when "4"
              @memory = size_in_bytes(device.elements["rasd:VirtualQuantity"].text,
                                      device.elements["rasd:AllocationUnits"].text)
            end
          end

          # disk volume
          diskref = doc.elements["//DiskSection/Disk"].attributes["ovf:fileRef"]
          @disk = doc.elements["//References/File[@ovf:id='file1']"].attributes["ovf:href"]
          @image_type = 'raw'
          @disk_bus = 'virtio'
          @machine_type = 'pc-1.2'

          # mac address
          # XXX we use only the first nic
          doc.elements.each("//vbox:Machine/Hardware//Adapter") do |ele|
            if ele.attributes['enabled'] == 'true'
              @mac = format_mac( ele.attributes['MACAddress'])
              break
            end
          end

          # the architecture is not defined in the ovf file
          # we try to guess from OSType
          # see https://www.virtualbox.org/browser/vbox/trunk/src/VBox/Main/include/ovfreader.h
          @arch = doc.elements["//vssd:VirtualSystemIdentifier"].text[-2..-1] == '64' ? "x86_64" : "i686"
        end

        def create_from_libvirt(definition)
          doc = REXML::Document.new definition
          @name = doc.elements["/domain/name"].text
          @uuid = doc.elements["/domain/uuid"].text if doc.elements["/domain/uuid"]
          memory_unit = doc.elements["/domain/memory"].attributes["unit"]
          @memory = size_in_bytes(doc.elements["/domain/memory"].text,
                                  memory_unit)
          @cpus = doc.elements["/domain/vcpu"].text
          @arch = doc.elements["/domain/os/type"].attributes["arch"]
          @machine_type = doc.elements["/domain/os/type"].attributes["machine"]
          @disk = doc.elements["//devices/disk/source"].attributes["file"]
          @mac = doc.elements["//devices/interface/mac"].attributes["address"]
          @network = doc.elements["//devices/interface/source"].attributes["network"]
          @image_type = doc.elements["//devices/disk/driver"].attributes["type"]
          @qemu_bin = doc.elements["/domain/devices/emulator"].text

          if doc.elements["//devices/graphics"]
            attrs = doc.elements["//devices/graphics"].attributes
            @gui = attrs["type"] == 'vnc'
            @vnc_port = attrs['port'].to_i
            @vnc_autoport = attrs['autoport'] == 'yes'
            @vnc_password = attrs['passwd']
          end
          @disk_bus = doc.elements["//devices/disk/target"].attributes["bus"]
        end

        def as_libvirt
          if @qemu_bin
            # user specified path of qemu binary
            qemu_bin_list = [@qemu_bin]
          else
            # RedHat and Debian-based systems have different executable names
            # depending on version/architectures
            qemu_bin_list = [ '/usr/bin/qemu-kvm', '/usr/bin/kvm' ]
            qemu_bin_list << '/usr/bin/qemu-system-x86_64' if @arch.match(/64$/)
            qemu_bin_list << '/usr/bin/qemu-system-i386'   if @arch.match(/^i.86$/)
          end

          qemu_bin = qemu_bin_list.detect { |binary| File.exists? binary }
          if not qemu_bin
            raise Errors::KvmNoQEMUBinary,
            :cause => @qemu_bin ?
            "Vagrantfile (specified binary: #{@qemu_bin})" : "QEMU installation"
          end

          xml = KvmTemplateRenderer.render("libvirt_domain", {
            :name => @name,
            :uuid => @uuid,
            :memory => size_from_bytes(@memory, "KiB"),
            :cpus => @cpus,
            :arch => @arch,
            :disk => @disk,
            :mac => format_mac(@mac),
            :network => @network,
            :gui => @gui,
            :machine_type => @machine_type,
            :image_type => @image_type,
            :qemu_bin => qemu_bin,
            :vnc_port => @vnc_port,
            :vnc_autoport => format_bool(@vnc_autoport),
            :vnc_password=> @vnc_password,
            :disk_bus => @disk_bus,
          })
          xml
        end

        def get_memory(unit="bytes")
          size_from_bytes(@memory, unit)
        end

        def set_mac(mac)
          @mac = format_mac(mac)
        end

        def unset_uuid
          @uuid = nil
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

        def format_bool(v)
          v ? "yes" : "no"
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
