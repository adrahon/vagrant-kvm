require 'spec_helper'

module VagrantPlugins
  module ProviderKvm
    module Driver
      describe Driver do
        let(:xml) { test_file "box.xml" }
        let(:name) { 'spec-test' }
        let(:disk_name) { 'spec-test' }
        let(:box_path) { test_file "box-disk1.img" }
        let(:box_pool) { test_file "" }
        let(:capacity) { {:size=>256, :unit=>'KB'} }
        let(:pool_path) { '/tmp/pool-storage' }
        let(:image_path) { '/tmp/pool-storage/box-disk1.img' }
        let(:image_type) { 'qcow2' }
        let(:uid) { 1000 }
        let(:gid) { 1000 }

        before do
          described_class.any_instance.stub(:load_kvm_module!) { true }
          described_class.any_instance.stub(:lookup_volume_path_by_name) { "/tmp/pool-storage/box-disk1.img" }
        end

        describe "#import" do
          subject do
            described_class.new(nil)
          end

          it "does not raise exeption" do
            expect do
              subject.set_name(name)
            end.to_not raise_exception
          end

          it "does not raise execption" do
            expect do
              subject.init_storage_pool("vagrant", pool_path)
            end.to_not raise_exception
          end

          it "does not raise exception" do
            expect do
              subject.init_storage_pool("vagrant", pool_path)
              subject.activate_storage_pool("vagrant")
              subject.create_volume(
                  :disk_name  => disk_name,
                  :capacity   => capacity,
                  :path       => image_path,
                  :image_type => image_type,
                  :box_path   => box_path,
                  :backing    => true)
              end.to_not raise_exception
          end

          it "does not raise exception" do
            expect do
              subject.set_name(name)
              subject.import(xml, disk_name)
            end.to_not raise_exception
          end
        end
      end
    end
  end
end
