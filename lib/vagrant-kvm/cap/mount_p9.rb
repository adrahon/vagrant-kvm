require "vagrant/util/retryable"

module VagrantPlugins
  module ProviderKvm
    module Cap
      class MountP9
        extend Vagrant::Util::Retryable

        def mount_p9_shared_folder(machine, ip, folders)
          folders.each do |name, opts|
            # Expand the guest path so we can handle things like "~/vagrant"
            expanded_guest_path = machine.guest.capability(
              :shell_expand_guest_path, opts[:guestpath])

            # Do the actual creating and mounting
            machine.communicate.sudo("mkdir -p #{expanded_guest_path}")

            # Mount
            mount_tag = opts[:hostpath].dup

            mount_opts="-o trans=virtio"
            if options[:owner] || options[:version] || options[:mount_options]
              mount_opts += ",access=#{options[:owner]}" if options[:owner]
              mount_opts += ",version=#{options[:version]}" if options[:version]
              mount_opts += ",#{opts[:mount_options]}" if opts[:mount_options]
            end

            mount_command = "mount -t 9p #{mount_opts} '#{mount_tag}' #{expanded_guest_path}"
            retryable(:on => Vagrant::Errors::LinuxP9MountFailed, :tries => 5, :sleep => 3) do
              machine.communicate.sudo(mount_command,
                                       :error_class => Vagrant::Errors::LinuxP9MountFailed)
            end
          end
        end
      end
    end
  end
end
