# vim: tabstop=2:shiftwidth=2:softtabstop=2
#
# Cookbook Name:: bcpc-hadoop
# Recipe:: disks
#
# Copyright 2014-2016, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

['xfsprogs', 'parted'].each do |package_name|
  package package_name do
    action :upgrade
  end
end

# Enumerate available disks and how they will be used
ruby_block 'enumerate-disks' do
  block do
    Chef::Resource::Ohai.new('reload-block-devices',
                             node.run_context).tap do |oh|
      oh.plugin 'block_device'
      oh.run_action :reload
    end

    #
    # node.run_state[:bcpc_hadoop_disks] is for values we generate at
    # runtime, by inspecting the state of the system.  These cannot be
    # overridden without changing the code.
    #
    # node[:bcpc][:hadoop][:disks] is for static attributes that we
    # know in advance.  These are easily overridden in an environment.
    #
    node.run_state[:bcpc_hadoop_disks] = {}
    node.run_state[:bcpc_hadoop_disks].tap do |disks|
      #
      # What disks will bcpc and bcpc-hadoop feel free to blank?
      # By default, all sd* devices (excluding sda) and all md* devices.
      #
      # On our EFI-based VM builds, it's very important to omit sdb, as
      # that is the 32 MB image containing iPXE.  (It's relatively
      # harmless to overwrite it, but it will cause graphite to fail when
      # /disk/0 fills up.)
      #
      all_drives = node[:block_device].keys.select do |dd|
        dd =~ /sd[a-i]?[b-z]/ ||
        dd =~ /md\d+/
      end

      disks[:available_disks] =
        if node[:dmi][:system][:product_name] == 'VirtualBox'

          # Reject all disks with fewer than a million blocks, so that we
          # do not attempt to use the iPXE image as a data disk.
          all_drives.reject do |dd|
            node[:block_device][dd].nil? ||
              node[:block_device][dd][:size].to_i < 10**6
          end
        else
          all_drives
        end
    end
  end
end

directory '/disk' do
  owner 'root'
  group 'root'
  mode 00755
  action :create
end

ruby_block 'format-disks' do
  block do
    #
    # Reservation requests and role_min_disks are set statically, in
    # Chef's "compile" pass.
    #
    reservation_requests =
      node[:bcpc][:hadoop][:disks][:reservation_requests]

    role_min_disk =
      node[:bcpc][:hadoop][:disks][:role_min_disk]

    #
    # The available disks list is generated dynamically, at converge time.
    #
    available_disks =
      node.run_state[:bcpc_hadoop_disks][:available_disks]

    if available_disks.any?
      available_disks.each_index do |i|
        Chef::Resource::Directory.new("/disk/#{i}",
                                      node.run_context).tap do |dd|
          dd.owner 'root'
          dd.group 'root'
          dd.mode 00755
          dd.recursive true
          dd.run_action(:create)
        end

        base_name = available_disks[i]

        #
        # If the raw disk has already been formatted with an FS, no
        # partition table is necessary.
        #
        # Otherwise, create a partition and format that.
        #
        require 'mixlib/shellout'

        fs_check =
          Mixlib::ShellOut.new('file', '-s', "/dev/#{base_name}")
        fs_check.run_command

        dev_name = if fs_check.status.success? &&
                       fs_check.stdout.include?('SGI XFS filesystem')
                     "/dev/#{base_name}"
                   else
                     "/dev/#{base_name}1"
                   end

        if dev_name.end_with?('1')
          unless ::File.exist?(dev_name)
            Chef::Resource::Execute.new("mklabel-#{base_name}",
                                        node.run_context).tap do |ee|
              ee.command "parted -s /dev/#{base_name} mklabel gpt"
              ee.run_action(:run)
            end

            Chef::Resource::Execute.new("mkpart-#{base_name}",
                                        node.run_context).tap do |ee|
              ee.command "parted -s /dev/#{base_name} " \
                'mkpart bach_data ext4 0% 100%'
              ee.run_action(:run)
            end
          end

        end

        check_command =
          Mixlib::ShellOut.new("file -s #{dev_name} | " \
                               "grep -q 'SGI XFS filesystem'")
        check_command.run_command

        unless check_command.status.success?
          Chef::Resource::Execute.new("mkfs-#{dev_name}",
                                      node.run_context).tap do |ee|
            ee.command "mkfs -t xfs -f #{dev_name} -L data_#{i}"
            ee.run_action(:run)
          end
        end

        uuid_command =
          Mixlib::ShellOut.new("blkid -o value -s UUID #{dev_name}")
        uuid_command.run_command

        unless uuid_command.status.success? && uuid_command.stdout.length > 1
          raise "Could not fetch UUID for filesystem on #{dev_name}"
        end

        mount_path = "/disk/#{i}"
        mount_device = uuid_command.stdout.chomp

        Chef::Resource::Mount.new(mount_path,
                                  node.run_context).tap do |mm|
          mm.device mount_device
          mm.device_type :uuid
          mm.fstype 'xfs'
          mm.options 'noatime,nodiratime,inode64'
          mm.run_action(:enable)
          mm.run_action(:mount)
        end

        # Delete duplicate fstab entries that don't use a UUID.
        Chef::Resource::Mount.new("stale-#{mount_path}",
                                  node.run_context).tap do |mm|
          mm.device dev_name
          mm.mount_point mount_path
          mm.run_action(:disable)
        end
      end

      # is our role included in the list
      if (node[:bcpc][:hadoop][:disks][:disk_reserve_roles] &
          node.roles).any?

        # make sure we have enough disks to fulfill reservations and
        # also normal opration of the DN and NN
        if reservation_requests.length > available_disks.length
          Chef::Application.fatal!('Reservations exceeds available disks')
        end

        if available_disks.length - reservation_requests.length < role_min_disk
          Chef::Application.fatal!('Minimum disk requirement not met')
        end

        mount_indexes =
          (0..(available_disks.length - 1)).to_a -
          reservation_requests.each_index.to_a

        node.run_state[:bcpc_hadoop_disks][:mounts] = mount_indexes
      else
        node.run_state[:bcpc_hadoop_disks][:mounts] =
          (0..(available_disks.length - 1)).to_a
      end
    else
      Chef::Application.fatal!('No available disks found!')
    end
  end
end
