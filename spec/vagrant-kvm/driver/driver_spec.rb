require 'spec_helper'

module VagrantPlugins
  module ProviderKvm
    module Driver
      describe Driver do
        let(:xml) { test_file "box.xml" }
        let(:volume_name) { "" }

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
              subject.import(xml, volume_name)
            end.to_not raise_exception
          end
        end
      end
    end
  end
end
