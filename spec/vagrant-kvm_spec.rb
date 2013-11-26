require 'spec_helper'

describe 'vagrant-kvm' do
  before(:all) do
    create_vagrantfile
  end

  describe 'up' do
    before(:all) do
      vagrant_up
    end

    after(:all) do
      vagrant_destroy
    end

    it'creates new libvirt domain' do
      expect(@libvirt.domains).to have(1).item
    end

    it 'starts created libvirt domain' do
      expect(@libvirt.domain).to be_active
    end

    it 'creates disk image file' do
      expect(pool_files).to have(1).item
    end

    it 'creates new pool' do
      expect(@libvirt.storage_pools).to include('vagrant')
    end

    it 'creates new network' do
      expect(@libvirt.networks).to include('vagrant')
    end
  end

  describe 'down' do
    before(:all) do
      vagrant_up
      vagrant_halt
    end

    after(:all) do
      vagrant_destroy
    end

    it 'shutdowns domain' do
      expect(@libvirt.domain).not_to be_active
    end
  end

  describe 'destroy' do
    before(:all) do
      vagrant_up
      vagrant_destroy
    end

    it 'undefines domain' do
      expect(@libvirt.domains).to be_empty
    end

    it 'removes disk image file' do
      expect(pool_files).to be_empty
    end

    it 'does not undefine storage pool' do
      expect(@libvirt.storage_pools).to include('vagrant')
    end

    it 'does not undefine new network' do
      expect(@libvirt.networks).to include('vagrant')
    end
  end
end
