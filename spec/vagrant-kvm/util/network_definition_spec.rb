require 'spec_helper'

describe VagrantPlugins::ProviderKvm::Util::NetworkDefinition do
  let(:name) { 'vagrant' }
  let(:xml) do
    <<-XML
      <network connections='1'>
        <name>vagrant</name>
        <uuid>0b9deaff-7665-d129-02e9-0f0a74054f87</uuid>
        <forward mode='nat'/>
        <bridge name='virbr1' stp='on' delay='0' />
        <mac address='52:54:00:DE:20:0C'/>
        <domain name='vagrant.local'/>
        <ip address='192.168.123.1' netmask='255.255.255.0'>
          <dhcp>
            <range start='192.168.123.100' end='192.168.123.200' />
            <host mac='00:69:0d:c2:52:f7' name='default' ip='192.168.123.10' />
          </dhcp>
        </ip>
      </network>
    XML
  end

  let(:definition) { described_class.new(name, xml) }
  subject { definition }

  it "should set the attributes properly" do
    subject.get(:forward).should == 'nat'
    subject.get(:domain_name).should == 'vagrant.local'
    subject.get(:base_ip).should == '192.168.123.1'
    subject.get(:netmask).should == '255.255.255.0'
    subject.get(:range).should == { :start => "192.168.123.100", :end => "192.168.123.200"}
    subject.get(:hosts).should == [ {
      :mac => '00:69:0d:c2:52:f7',
      :name => 'default',
      :ip => '192.168.123.10',
    }]
  end

  
  describe "#==" do
    it "returns true if and only if all attributes are equal" do
      def1 = described_class.new(name, xml)
      def2 = described_class.new(name, xml)

      def1.should == def2

      def2.set(:netmask, '255.255.0.0')
      def1.should_not == def2
    end
  end

  describe "#as_xml" do
    it "should be symetrical" do
      def1 = described_class.new(name, subject.as_xml)
      subject.should == def1
      subject.as_xml.should == def1.as_xml
    end
  end
end
