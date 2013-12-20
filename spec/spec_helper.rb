require 'vagrant-kvm'
require 'support/libvirt_helper'
require 'support/vagrant_kvm_helper'
require 'pry'

def libvirt
  @libvirt ||= LibvirtHelper.new
end

RSpec.configure do |spec|
  spec.include VagrantKvmHelper

  spec.before(:all) do

    # make sure everything is run in tmp
    Dir.chdir '/tmp'
  end

  spec.after(:all) do
    libvirt.connection.close
  end

  at_exit do
    File.delete('Vagrantfile') if File.exists?('Vagrantfile')
  end
end

def test_file(path)
  File.join(File.dirname(__FILE__), "test_files", path)
end
