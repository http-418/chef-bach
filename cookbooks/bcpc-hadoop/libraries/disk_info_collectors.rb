module BACH
  module DiskInfoCollectors
    #
    # Parses 'blkid' output
    #
    # Takes no arguments.
    #
    # Returns a hash with block device paths as keys.
    # Each value is a hash of K/Vs returned by the blkid tool.
    #
    def parsed_blkid
      require 'mixlib/shellout'
      require 'pry'

      cc = Mixlib::ShellOut.new('blkid')
      cc.run_command
      cc.error!

      cc.stdout.split("\n").reject do |ll|
        ll =~ /^\s*$/
      end.map do |ll|
        md = /^(?<fs_spec>.*?): (?<data>.*)$/.match(ll)

        # Device name.
        fs_spec = md[:fs_spec]

        # Key/value pairs.
        data = md[:data].split(/\s+/).map do |pair|
          (key, value) = pair.split('=')
          value.gsub(/"$/, '').gsub(/^"/, '')
          [key, value]
        end

        Hash[fs_spec, Hash[data]]
      end.reduce({}, :merge)
    end

    #
    # Parses /etc/fstab along the rules laid out in 'man 5 fstab'
    #
    # Takes an optional argument.  (Defaults to /etc/fstab)
    #
    # Returns a list of hashes with key names based on the fields
    # defined in 'man 5 fstab'
    #
    def parsed_fstab(target_file='/etc/fstab')
      File.readlines(target_file).reject do |ll|
        # Drop comments and blank lines.
        ll =~ /^\s*$/ || ll =~ /^\s*#/
      end.map do |ll|
        fields = ll.split(/\s+/)

        raise 'Could not parse /etc/fstab!' if fields.length == 0

        # Pad with nils for missing fields.
        gap = 6 - fields.length
        if gap > 0
          fields += [nil] * gap
        end

        # Truncate any extra elements.
        fields = fields[0..5]

        #
        # Turn the list of fields into a list of pairs taking the form:
        #   [field name, field value]
        #
        # The values may be nil but they are guaranteed to be present.
        #
        pairs = [:fs_spec,
                 :fs_file,
                 :fs_vfstype,
                 :fs_mntops,
                 :fs_freq,
                 :fs_passno].zip(fields)

        Hash[pairs]
      end
    end

    #
    # Parses /proc/mounts with the same logic as parsed_fstab.
    #
    # Takes no arguments.
    # Returns the same values as parsed_fstab.
    #
    def parsed_proc_mounts
      parsed_fstab('/proc/mounts')
    end

    #
    # Free block devices are:
    # - Not members of an MD device.
    # - Not LVM PVs.
    # - Not backing swap.
    # - Not underlying the /boot or /boot/efi filesystems.
    #
    # These block devices may still be in use by:
    # - Data volumes (mounted or not)
    #
    def free_block_devices

    end
  end
end
