require 'spec_helper'

module VagrantPlugins
  module ProviderKvm
    module Driver
      describe Driver do
        let(:xml) { test_file "box.xml" }
        let(:volume_name) { "" }
        let(:disk_name) { 'spec-test' }
        let(:box_path) { test_file "box-disk1.img" }
        let(:box_pool) { test_file "" }
        let(:capacity) { {:size=>256, :unit=>'KB'} }
        let(:image_path) { '/tmp/pool-storage/box-disk1.img' }
        let(:image_type) { 'qcow2' }

        before do
          described_class.any_instance.stub(:load_kvm_module!) { true }
          described_class.any_instance.stub(:lookup_volume_path_by_name) { "/tmp/pool-storage/box-disk1.img" }
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
              subject.create_volume(disk_name, capacity, image_path,
                               image_type, box_pool, box_path, true)
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
