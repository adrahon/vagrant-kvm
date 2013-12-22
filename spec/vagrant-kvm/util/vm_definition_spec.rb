require 'spec_helper'

describe VagrantPlugins::ProviderKvm::Util::VmDefinition do
  let(:definition) { VagrantPlugins::ProviderKvm::Util::VmDefinition.new(File.read(path)) }
  subject { definition }

  context "with an simple definition" do
    let(:path) { test_file("box.xml") }

    describe "#as_xml" do
      subject { definition.as_xml }

      it "sets the CPU count properly" do
        subject.should include("<vcpu placement='static'>1</vcpu>")
      end

      it "sets the VNC port and autoport" do
        definition.update gui: true,
          vnc_port: 1234,
          vnc_autoport: false,
          vnc_password: 'abc123'

        subject.should include("<graphics type='vnc' port='1234' autoport='false'")

        new_definition = VagrantPlugins::ProviderKvm::Util::VmDefinition.new(subject)
        new_definition.get(:gui).should be_true
        new_definition.get(:vnc_port).should == 1234
        new_definition.get(:vnc_autoport).should be_false
        new_definition.get(:vnc_password).should == 'abc123'
      end

      it "should set and load the GUI settings" do
        should_set(:gui, true) do |xml|
          xml.should include("<graphics type='vnc'")
        end
      end

      it "sets machine type" do
        should_default(:machine_type, "pc-1.2")
        should_set(:machine_type, "pc-i440fx-1.4")
      end

      it "sets the network driver type" do
        should_default(:network_model, "virtio")
        should_set(:network_model, "ne2k_pci")
      end

      it "doesn't set the network driver if network_mode=:default" do
        should_set(:network_model, :default) do |xml|
          doc = REXML::Document.new(xml)
          doc.elements["//devices/interface/model"].should be_nil
        end
      end

      it "sets the video type" do
        should_default(:video_model, "cirrus")
        should_set(:video_model, "vga")
      end
    end
  end

  private
  def should_set(key, value)
    definition.update(key => value)
    definition.get(key).should == value
    yield subject if block_given?

    # Validates that it's symetrical
    new_definition = VagrantPlugins::ProviderKvm::Util::VmDefinition.new(subject)
    new_definition.get(key).should == value
  end

  def should_default(key, value)
    definition.get(key).should == value
  end
end
