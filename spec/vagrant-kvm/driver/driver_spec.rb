require 'spec_helper'

module VagrantPlugins
  module ProviderKvm
    module Driver
      describe Driver do
        let(:xml) { test_file "box.xml" }
        let(:volume_name) { "" }

        before do
          described_class.any_instance.stub(:load_kvm_module!) { true }
          described_class.any_instance.stub(:init_storage_pool!) { true }
          described_class.any_instance.stub(:lookup_volume_path_by_name) { "/tmp/spool-directory/box.img" }
        end

        describe "#import" do

          subject do
            described_class.new(nil)
          end

          it "does not raise execption" do
            expect do
              subject.init_storage("/tmp")
            end.to_not raise_exception
          end

          it "does not raise exception" do
            expect do
              subject.import(xml, volume_name)
            end.to_not raise_exception
          end
        end
      end
    end
  end
end
