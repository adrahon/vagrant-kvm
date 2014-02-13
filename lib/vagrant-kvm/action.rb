require "pathname"

require "vagrant/action/builder"

module VagrantPlugins
  module ProviderKvm
    module Action
      # Include the built-in modules so that we can use them as top-level
      # things.
      include Vagrant::Action::Builtin

      # This action boots the VM, assuming the VM is in a state that requires
      # a bootup (i.e. not saved).
      def self.action_boot
        Vagrant::Action::Builder.new.tap do |b|
          b.use Network
          b.use Provision
          b.use Vagrant::Action::Builtin::HandleForwardedPortCollisions
          b.use PrepareNFSValidIds
          b.use SyncedFolderCleanup
          b.use SyncedFolders
          b.use PrepareNFSSettings
          b.use SetHostname
          b.use Customize, "pre-boot"
          b.use ForwardPorts
          b.use Boot
          if Vagrant::VERSION >= "1.3.0"
            b.use WaitForCommunicator, [:running]
          end
          b.use ShareFolders
          b.use Customize, "post-boot"
        end
      end

      # This is the action that is primarily responsible for completely
      # freeing the resources of the underlying virtual machine.
      def self.action_destroy
        Vagrant::Action::Builder.new.tap do |b|
          b.use CheckKvm
          b.use Call, Created do |env1, b2|
            if !env1[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use Call, DestroyConfirm do |env2, b3|
              if env2[:result]
                b3.use ConfigValidate
                b3.use EnvSet, :force_halt => true
                b3.use action_halt
                b3.use PrepareNFSSettings
                b3.use PrepareNFSValidIds
                b3.use SyncedFolderCleanup
                b3.use PrepareNFSSettings
                b3.use Destroy
              else
                b3.use MessageWillNotDestroy
              end
            end
          end
        end
      end

      # This is the action that is primarily responsible for halting
      # the virtual machine, gracefully or by force.
      def self.action_halt
        Vagrant::Action::Builder.new.tap do |b|
          b.use CheckKvm
          b.use Call, Created do |env, b2|
            if env[:result]
              b2.use Call, IsPaused do |env2, b3|
                next if !env2[:result]
                b3.use Resume
              end

              b2.use ClearForwardedPorts
              b2.use Call, GracefulHalt, :shutoff, :running do |env2, b3|
                if !env2[:result]
                  b3.use ForcedHalt
                end
                b3.use ResetImagePermission
              end
            else
              b2.use MessageNotCreated
            end
          end
        end
      end

      # This action packages the virtual machine into a single box file.
      def self.action_package
        Vagrant::Action::Builder.new.tap do |b|
          b.use CheckKvm
          b.use Call, Created do |env1, b2|
            if !env1[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use SetupPackageFiles
            b2.use action_halt
            b2.use PrepareNFSSettings
            b2.use PrepareNFSValidIds
            b2.use SyncedFolderCleanup
            b2.use PrepareNFSSettings
            b2.use Export
            b2.use PackageVagrantfile
            b2.use Package
          end
        end
      end

      # This action just runs the provisioners on the machine.
      def self.action_provision
        Vagrant::Action::Builder.new.tap do |b|
          b.use CheckKvm
          b.use ConfigValidate
          b.use Call, Created do |env1, b2|
            if !env1[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use Call, IsRunning do |env2, b3|
              if !env2[:result]
                b3.use MessageNotRunning
                next
              end

              b3.use Provision
            end
          end
        end
      end

      # This action is responsible for reloading the machine, which
      # brings it down, sucks in new configuration, and brings the
      # machine back up with the new configuration.
      def self.action_reload
        Vagrant::Action::Builder.new.tap do |b|
          b.use CheckKvm
          b.use Call, Created do |env1, b2|
            if !env1[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use ConfigValidate
            b2.use action_halt
            b2.use action_start
          end
        end
      end

      # This is the action that is primarily responsible for resuming
      # suspended machines.
      def self.action_resume
        Vagrant::Action::Builder.new.tap do |b|
          b.use CheckKvm
          b.use Call, Created do |env, b2|
            if env[:result]
              b2.use ResumeNetwork
              b2.use Resume
            else
              b2.use MessageNotCreated
            end
          end
        end
      end

      # This is the action that will exec into an SSH shell.
      def self.action_ssh
        Vagrant::Action::Builder.new.tap do |b|
          b.use CheckKvm
          b.use CheckCreated
          b.use CheckRunning
          b.use SSHExec
        end
      end

      # This is the action that will run a single SSH command.
      def self.action_ssh_run
        Vagrant::Action::Builder.new.tap do |b|
          b.use CheckKvm
          b.use CheckCreated
          b.use CheckRunning
          b.use SSHRun
        end
      end

      # This action starts a VM, assuming it is already imported and exists.
      # A precondition of this action is that the VM exists.
      def self.action_start
        Vagrant::Action::Builder.new.tap do |b|
          b.use CheckKvm
          b.use ConfigValidate
          b.use Call, IsRunning do |env, b2|
            # If the VM is running, then our work here is done, exit
            next if env[:result]

            b2.use Call, IsSaved do |env2, b3|
              if env2[:result]
                # The VM is saved, so just resume it
                b3.use action_resume
                next
              end

              b3.use Call, IsPaused do |env3, b4|
                if env3[:result]
                  b4.use ResumeNetwork
                  b4.use Resume
                  next
                end

                # The VM is not saved, so we must have to boot it up
                # like normal. Boot!
                b4.use PrepareGui
                b4.use action_boot
              end
            end
          end
        end
      end

      # This is the action that is primarily responsible for suspending
      # the virtual machine.
      def self.action_suspend
        Vagrant::Action::Builder.new.tap do |b|
          b.use CheckKvm
          b.use Call, Created do |env, b2|
            if env[:result]
              b2.use Suspend
            else
              b2.use MessageNotCreated
            end
          end
        end
      end

      # This action brings the machine up from nothing, including importing
      # the box, configuring metadata, and booting.
      def self.action_up
        Vagrant::Action::Builder.new.tap do |b|
          b.use CheckKvm
          b.use SetName
          b.use ConfigValidate
          b.use InitStoragePool
          b.use Call, Created do |env, b2|
            # If the VM is NOT created yet, then do the setup steps
            if !env[:result]
              b2.use CheckBox
              b2.use SetName
              b2.use Customize, "pre-import"
              b2.use Import
              b2.use MatchMACAddress
            end
          end
          b.use action_start
        end
      end

      # The autoload farm
      action_root = Pathname.new(File.expand_path("../action", __FILE__))
      autoload :Boot, action_root.join("boot")
      autoload :CheckBox, action_root.join("check_box")
      autoload :CheckCreated, action_root.join("check_created")
      autoload :CheckKvm, action_root.join("check_kvm")
      autoload :CheckRunning, action_root.join("check_running")
      autoload :ClearForwardedPorts, action_root.join("clear_forwarded_ports")
      autoload :Customize, action_root.join("customize")
      autoload :Created, action_root.join("created")
      autoload :Destroy, action_root.join("destroy")
      autoload :DestroyConfirm, action_root.join("destroy_confirm")
      autoload :Export, action_root.join("export")
      autoload :ForcedHalt, action_root.join("forced_halt")
      autoload :ForwardPorts, action_root.join("forward_ports")
      autoload :Import, action_root.join("import")
      autoload :InitStoragePool, action_root.join("init_storage_pool")
      autoload :IsPaused, action_root.join("is_paused")
      autoload :IsRunning, action_root.join("is_running")
      autoload :IsSaved, action_root.join("is_saved")
      autoload :MatchMACAddress, action_root.join("match_mac_address")
      autoload :MessageNotCreated, action_root.join("message_not_created")
      autoload :MessageNotRunning, action_root.join("message_not_running")
      autoload :MessageWillNotDestroy, action_root.join("message_will_not_destroy")
      autoload :Network, action_root.join("network")
      autoload :PackageVagrantfile, action_root.join("package_vagrantfile")
      autoload :Package, action_root.join("package")
      autoload :PrepareGui, action_root.join("prepare_gui")
      autoload :PrepareNFSSettings, action_root.join("prepare_nfs_settings")
      autoload :PrepareNFSValidIds, action_root.join("prepare_nfs_valid_ids")
      autoload :PruneNFSExports, action_root.join("prune_nfs_exports")
      autoload :ResetImagePermission, action_root.join("reset_image_permission")
      autoload :Resume, action_root.join("resume")
      autoload :ResumeNetwork, action_root.join("resume_network")
      autoload :SetName, action_root.join("set_name")
      autoload :SetupPackageFiles, action_root.join("setup_package_files")
      autoload :ShareFolders, action_root.join("share_folders")
      autoload :Suspend, action_root.join("suspend")
    end
  end
end
