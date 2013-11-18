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
        definition.vnc_autoport = true
        subject.should include("<graphics type='vnc' port='1234' autoport='yes'/>")
      end

      it "defaults to VNC port to -1 and autoport to true" do
        definition.gui = true
        subject.should include("<graphics type='vnc' port='-1' autoport='yes'/>")
      end
    end
  end
end
