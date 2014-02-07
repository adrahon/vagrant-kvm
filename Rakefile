require 'rubygems'
require 'bundler/setup'

# Immediately sync all stdout so that tools like buildbot can
# immediately load in the output.
$stdout.sync = true
$stderr.sync = true

# Change to the directory of this file.
Dir.chdir(File.expand_path("../", __FILE__))

# This installs the tasks that help with gem creation and
# publishing.
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

namespace :box do
  desc 'Downloads and adds vagrant box for testing.'
  task :add do
    system 'bundle exec vagrant box add vagrant-kvm-specs http://cloud-images.ubuntu.com/vagrant/precise/current/precise-server-cloudimg-amd64-vagrant-disk1.box'
  end

  desc 'Prepares VirtualBox box for usage with KVM.'
  task :prepare do
    system 'bundle exec vagrant plugin install vagrant-mutate'
    system 'bundle exec vagrant mutate vagrant-kvm-specs kvm'
    system 'bundle exec vagrant box remove vagrant-kvm-specs virtualbox'
  end

  desc 'Removes testing vagrant box.'
  task :remove do
    system 'bundle exec vagrant box remove vagrant-kvm-specs kvm'
  end
end

task :default => :spec
