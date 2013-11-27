require 'libvirt'

class LibvirtHelper

  attr_reader :connection

  def initialize
    @connection = Libvirt.open('qemu:///system')
  end

  def domains
    # list_domains returns IDs of active domains
    # list_defined_domains returns names of inactive domains
    @connection.list_domains + @connection.list_defined_domains
  end

  def domain
    domain = domains.first
    case domain
    when Integer
      @connection.lookup_domain_by_id(domain)
    when String
      @connection.lookup_domain_by_name(domain)
    else
      raise "Cannot find domain!"
    end
  end

  def storage_pools
    @connection.list_storage_pools
  end

  def networks
    @connection.list_networks
  end

end # LibvirtHelper
