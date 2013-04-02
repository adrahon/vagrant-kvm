# Utility class to manage libvirt network definition
require 'vagrant/util/template_renderer'
require "nokogiri"

module VagrantPlugins
  module ProviderKvm
    module Util
      class NetworkDefinition
        # For TemplateRenderer
        include Vagrant::Util
        # Attributes of the Network
        attr_reader :name
        attr_reader :domain_name
        attr_reader :base_ip

        def initialize(name, definition=nil)
          @name = name
          if definition
            doc = Nokogiri::XML(definition)
            @forward = doc.at_css("network forward")["mode"] if doc.at_css("network forward")
            @domain_name = doc.at_css("network domain")["name"] if doc.at_css("network domain")
            @base_ip = doc.at_css("network ip")["address"]
            @netmask = doc.at_css("network ip")["netmask"]
            @range = {
              :start => doc.at_css("network ip dhcp range")["start"],
              :end => doc.at_css("network ip dhcp range")["end"]
            }
            @hosts = []
            doc.css("network ip dhcp host").each do |host|
              @hosts << {
                :mac => host["mac"],
                :name => host["name"],
                :ip => host["ip"]
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
          doc = Nokogiri::XML(xml)
          entry_point = doc.at_css("network ip dhcp range")
          @hosts.each do |host|
            entry_point.add_next_sibling "<host mac='#{host[:mac]}' name='#{host[:name]}' ip='#{host[:ip]}' />"
          end
          doc.to_xml
        end

      end
    end
  end
end
