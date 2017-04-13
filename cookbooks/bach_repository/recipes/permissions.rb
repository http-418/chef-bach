#
# Cookbook Name:: bach_repository
# Recipe:: permissions
#
# chef-bach uses a non-standard umask during chef runs.  Many, many
# tools fail to account for unexpected umasks, and bad permissions
# are written to disk.  This recipe exists to fix all permissions on
# the repo at once.
#
require 'pathname'

bins_dir = node['bach']['repository']['bins_directory']

ruby_block 'correct_bins_directory_parent_permissions' do
  block do
    Pathname.new(bins_dir).descend do |path|
      path.chmod(0755)
    end
  end
end

execute "find '#{bins_dir}' -type d -exec chmod ugo+rx {} \\;"
execute "find '#{bins_dir}' -type f -exec chmod ugo+r {} \\;"
