require 'spec_helper'
require "vagrant-kvm/config"

describe  VagrantPlugins::ProviderKvm::Config do
  describe "#image_type" do
    it "defaults to qcow2" do
      should_default(:image_type, 'qcow2')
    end
  end

  describe "#image_backing" do
    it "default to true" do
      subject.finalize!
      subject.image_backing.should be_true
    end
  end

  describe "#cpu_model" do
    it "default to x86-64" do
      should_default(:cpu_model, 'x86_64')
    end
  end

  describe "#core_number" do
    it "default to 1" do
      should_default(:core_number, 1)
    end
  end

  describe "#machine_type" do
    it "defaults to pc-1.2" do
      should_default(:machine_type, "pc-1.2")
    end
  end

  describe "#vnc_port" do
    it "defaults to -1" do
      should_default(:vnc_port, -1)
    end
  end

  describe "#vnc_password" do
    it "defaults to nil" do
      should_default(:vnc_password, nil)
    end
  end

  describe "#network_model" do
    it "defaults to 'virtio'" do
      should_default(:network_model, 'virtio')
    end
  end

  describe "#video_model" do
    it "defaults to 'virtio'" do
      should_default(:video_model, 'cirrus')
    end
  end

  describe "#image_mode" do
    it "sets image_backing to false if clone" do
      subject.image_mode = 'clone'
      subject.finalize!
      subject.image_backing.should be_false
    end

    it "sets image_backing to true if cow" do
      subject.image_mode = 'cow'
      subject.finalize!
      subject.image_backing.should be_true
    end
  end

  private
  def should_default(field, default_value)
    instance = described_class.new
    instance.send(field).should == described_class::UNSET_VALUE
    instance.finalize!
    instance.send(field).should == default_value
  end
end
