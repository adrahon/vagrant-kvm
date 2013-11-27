FileUtils.rm_rf "~/.vagrant.d/boxes/test_box/"

require 'vagrant-kvm'
require 'pry'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
end

def test_file(path)
  File.join(File.dirname(__FILE__), "test_files", path)
end
