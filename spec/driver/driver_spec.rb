require 'spec_helper'

module VagrantPlugins
  module ProviderKvm
    module Driver
      describe Driver do
        let(:xml) { test_file "box.xml" }
        let(:box_type) { "" }
        let(:volume_name) { "" }
        let(:image_type) { "raw" }
        let(:qemu_bin) { nil }
        let(:cpus) { nil }
        let(:memory_size) { nil }
        let(:cpu_model) { nil }
        let(:computer_type) { nil }
        let(:network_model) { nil }

        describe "#import" do
          # FIXME All of these required stubs are a symptom of bad design in the
          # driver class. 
          let(:volume) { double(path: "foo") }
          let(:pool) { double(refresh: nil, lookup_volume_by_name: volume) }
          let(:domain) { double(uuid: "abc") }
          let(:conn) { double(version: 1000000000, 
                              lookup_storage_pool_by_name: pool, 
                              define_domain_xml: domain) }
          subject do
            described_class.new(nil, conn)
          end

          it "does not raise exception" do
            expect do
              subject.import(xml, box_type, volume_name ,image_type, qemu_bin, cpus, memory_size, cpu_model, computer_type, network_model)
            end.to_not raise_exception
          end
        end
      end
    end
  end
end
