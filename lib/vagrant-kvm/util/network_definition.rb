# Utility class to manage libvirt network definition
require "rexml/document"

module VagrantPlugins
  module ProviderKvm
    module Util
      class NetworkDefinition
        include DefinitionAttributes

        def initialize(name, definition=nil)
          # create with defaults
          # XXX defaults should move to config
          self.attributes = {
            :forward => "nat",
            :domain_name => "vagrant.local",
            :base_ip => "192.168.123.1",
            :netmask => "255.255.255.0",
            :range => {
              :start => "192.168.123.100",
              :end => "192.168.123.200",
            },
            :hosts => [],
            name: name,
          }

          if definition
            doc = REXML::Document.new definition
            if doc.elements["/network/forward"]
              set(:forward, doc.elements["/network/forward"].attributes["mode"]) 
            end

            if doc.elements["/network/domain"]
              set(:domain_name, doc.elements["/network/domain"].attributes["name"]) 
            end
            set(:base_ip, doc.elements["/network/ip"].attributes["address"])
            set(:netmask, doc.elements["/network/ip"].attributes["netmask"])
            set(:range, {
              :start => doc.elements["/network/ip/dhcp/range"].attributes["start"],
              :end => doc.elements["/network/ip/dhcp/range"].attributes["end"]
            })
            hosts = []
            doc.elements.each("/network/ip/dhcp/host") do |host|
              hosts << {
                :mac => host.attributes["mac"],
                :name => host.attributes["name"],
                :ip => host.attributes["ip"]
              }
            end
            set(:hosts, hosts)
          end
        end

        def ==(other)
          # Don't compare the hosts
          [:forward, :domain_name, :base_ip, :netmask, :range,].all? do |key|
            get(key) == other.get(key)
          end
        end

        def as_xml
          KvmTemplateRenderer.render("libvirt_network", attributes.dup)
        end

        # Provide host xml block to update definiton through libvirt(>= 0.5.0)
        def as_host_xml
          xml = ""
          hosts.each do |host|
            xml = xml + "<host mac='#{host[:mac]}' name='#{host[:name]}' ip='#{host[:ip]}' />"
          end
          xml
        end

        # Returns xml definition for one host
        def get_host_xml(mac)
          xml = ""
          hosts.each do |host|
            if host[:mac] == mac
             return "<host mac='#{host[:mac]}' name='#{host[:name]}' ip='#{host[:ip]}' />"
            end
          end
          xml
        end

        def hosts
          get(:hosts)
        end

        def already_exist_host?(config)
          hosts.each do |host|
            return true if host[:mac]==config[:mac]
          end
          false
        end

        def already_exist_ip?(config)
          hosts.each do |host|
            return true if host[:ip]==config[:ip]
          end
          false
        end
      end
    end
  end
end
