# Utility class to manage libvirt network definition
require "rexml/document"

module VagrantPlugins
  module ProviderKvm
    module Util
      class NetworkDefinition
        # Attributes of the Network
        attr_reader :name
        attr_reader :domain_name
        attr_reader :base_ip

        def initialize(name, definition=nil)
          @name = name
          if definition
            doc = REXML::Document.new definition
            @forward = doc.elements["/network/forward"].attributes["mode"] if doc.elements["/network/forward"]
            @domain_name = doc.elements["/network/domain"].attributes["name"] if doc.elements["/network/domain"]
            @base_ip = doc.elements["/network/ip"].attributes["address"]
            @netmask = doc.elements["/network/ip"].attributes["netmask"]
            @range = {
              :start => doc.elements["/network/ip/dhcp/range"].attributes["start"],
              :end => doc.elements["/network/ip/dhcp/range"].attributes["end"]
            }
            @hosts = []
            doc.elements.each("/network/ip/dhcp/host") do |host|
              @hosts << {
                :mac => host.attributes["mac"],
                :name => host.attributes["name"],
                :ip => host.attributes["ip"]
              }
            end
          else
            # create with defaults
            # XXX defaults should move to config
            @forward = "nat"
            @domain_name = "vagrant.local"
            @base_ip = "192.168.192.1"
            @netmask = "255.255.255.0"
            @range = {
              :start => "192.168.192.100",
              :end => "192.168.192.200"}
            @hosts = []
          end
        end

        def configure(config)
          config = {
            :forward => @forward,
            :domain_name => @domain_name,
            :base_ip => @base_ip,
            :netmask => @netmask,
            :range => @range,
            :hosts => @hosts}.merge(config)

            @forward = config[:forward]
            @domain_name = config[:domain_name]
            @base_ip = config[:base_ip]
            @netmask = config[:netmask]
            @range = config[:range]
            @hosts = config[:hosts]
        end

        def as_xml
          xml = <<-EOXML
            <network>
              <name>#{@name}</name>
              <forward mode='#{@forward}'/>
              <domain name='#{@domain_name}'/>
              <ip address='#{@base_ip}' netmask='#{@netmask}'>
                <dhcp>
                <range start='#{@range[:start]}' end='#{@range[:end]}' />
                </dhcp>
              </ip>
            </network>
          EOXML
          xml = inject_hosts(xml) if @hosts.length > 0
          xml
        end

        def add_host(host)
          cur_host = @hosts.detect {|h| h[:mac] == host[:mac]}
          if cur_host
            cur_host[:ip] = host[:ip]
            cur_host[:name] = host[:name]
          else
            @hosts << {
              :mac => host[:mac],
              :name => host[:name],
              :ip => host[:ip]}
          end
        end

        def inject_hosts(xml)
          doc = REXML::Document.new xml
          entry_point = doc.elements["/network/ip/dhcp"]
          @hosts.each do |host|
            entry_point.add_element("host", {'mac' => host[:mac], 'name' => host[:name], 'ip' => host[:ip]})
          end
          doc.to_s
        end

      end
    end
  end
end
