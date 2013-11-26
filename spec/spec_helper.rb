require 'support/libvirt_helper'
require 'support/vagrant_kvm_helper'

# make sure everything is run in tmp
Dir.chdir '/tmp'


RSpec.configure do |spec|
  spec.include VagrantKvmHelper

  spec.before(:all) do
    @libvirt = LibvirtHelper.new
  end

  spec.after(:all) do
    @libvirt.connection.close
  end

  at_exit do
    File.delete('Vagrantfile') if File.exists?('Vagrantfile')
  end
end
