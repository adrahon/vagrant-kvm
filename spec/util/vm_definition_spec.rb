require 'spec_helper'

describe VagrantPlugins::ProviderKvm::Util::VmDefinition do
  let(:definition) { VagrantPlugins::ProviderKvm::Util::VmDefinition.new(File.read(path), source_type) }
  subject { definition }

  ["box.ovf", "box2.ovf"].each do |file|
    context "with an OVF definition (file #{file})" do
      let(:path) { test_file(file) }
      let(:source_type) { 'ovf' }

      it "parses it correctly" do
        subject.cpus.should == "1"
      end
    end
  end

  context "with an simple definition" do
    let(:path) { test_file("box.ovf") }
    let(:source_type) { 'ovf' }

    describe "#as_libvirt" do
      subject { definition.as_libvirt }

      it "sets the CPU count properly" do
        subject.should include("<vcpu placement='static'>1</vcpu>")
      end

      it "sets the VNC port and autoport" do
        definition.gui = true
        definition.vnc_port = 1234
        definition.vnc_autoport = false
        definition.vnc_password = 'abc123' 
        subject.should include("<graphics type='vnc' port='1234' autoport='no'")

        new_definition = VagrantPlugins::ProviderKvm::Util::VmDefinition.new(subject, 'libvirt')
        new_definition.gui.should be_true
        new_definition.vnc_port.should == 1234
        new_definition.vnc_autoport.should be_false
        new_definition.vnc_password.should == 'abc123'
      end

      it "should set and load the GUI settings" do
        should_set(:gui, true) do |xml|
          xml.should include("<graphics type='vnc' port='-1' autoport='no'")
        end
      end

      it "sets machine type" do
        should_default(:machine_type, "pc-1.2")
        should_set(:machine_type, "pc-i440fx-1.4")
      end
    end
  end

  private
  def should_set(key, value)
    definition.send(:"#{key}=", value)
    definition.send(key).should == value
    yield subject if block_given?

    # Validates that it's symetrical
    new_definition = VagrantPlugins::ProviderKvm::Util::VmDefinition.new(subject, 'libvirt')
    new_definition.send(key).should == value
  end

  def should_default(key, value)
    definition.send(key).should == value
  end
end
