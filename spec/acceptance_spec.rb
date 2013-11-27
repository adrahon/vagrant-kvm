require 'spec_helper'

require Vagrant.source_root.join("plugins/kernel_v2/config/vm")

# This test is far from perfect. If attemps to boot an empty machine, which
# exercises a lot of this plugins code. It does not however makes any assertion
# of the state of that machine. This needs improving in many ways, but is still
# much better than nothing.

describe "Vagrant KVM Plugin" do
  let(:folder) { "spec/tmp" }
  let(:environment) { Vagrant::Environment.new(cwd: folder) }

  before do
    # Cleanup any previous import
    FileUtils.rm_rf "~/.vagrant.d/boxes/test_box/"
    FileUtils.mkdir_p folder
    FileUtils.cp test_file("Vagrantfile"), folder

    # Vagrant will die trying to mounth these shares as we're not booting a
    # *real* box. Stub that stuff out.
    VagrantPlugins::Kernel_V2::VMConfig.any_instance.stub(synced_folders: {})
    VagrantPlugins::ProviderKvm::Action::ShareFolders.any_instance.stub(
      prepare_folders: nil,
      create_metadata: nil)
  end

  after do
    # Force destroy to cleanup any old env
    begin 
      environment.cli("destroy", "-f")
    rescue
    end
    FileUtils.rm_rf "~/.vagrant.d/boxes/test_box/"
  end

  it "adds a box, ups it and then destroy it" do
    environment.cli("up", "--provider=kvm").should == 0
    environment.cli("halt").should == 0
    environment.cli("destroy", "-f").should == 0
  end
end
