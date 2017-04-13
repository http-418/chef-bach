#
# Cookbook Name:: bach_repository
# Recipe:: gems
#
include_recipe 'bach_repository::directory'
include_recipe 'bach_repository::tools'
bins_dir = node['bach']['repository']['bins_directory']
gems_dir = node['bach']['repository']['gems_directory']
gem_binary = node['bach']['repository']['gem_bin']
bundler_bin = node['bach']['repository']['bundler_bin']
bundle_directory =
  File.join(node['bach']['repository']['repo_directory'], 'vendor', 'bundle')

package ['libaugeas-dev', 'libkrb5-dev'] do
  action :upgrade
end

directory "#{node['bach']['repository']['repo_directory']}/vendor" do
  owner 'vagrant'
  mode 0755
  recursive true
end

directory "#{node['bach']['repository']['repo_directory']}/.bundle" do
  owner 'vagrant'
  mode 0755
end

file "#{node['bach']['repository']['repo_directory']}/.bundle/config" do
  content <<-EOF.gsub(/^ {4}/,'')
    ---
    BUNDLE_PATH: '#{bundle_directory}'
    BUNDLE_DISABLE_SHARED_GEMS: 'true'
  EOF
  owner 'vagrant'
  action :create
end

execute 'bundler install' do
  cwd node['bach']['repository']['repo_directory']
  command "#{bundler_bin} install"
  # restore system PKG_CONFIG_PATH so mkmf::pkg_config()
  # can find system libraries
  environment \
    'PKG_CONFIG_PATH' => %w(/usr/lib/pkgconfig
                            /usr/lib/x86_64-linux-gnu/pkgconfig
                            /usr/share/pkgconfig).join(':'),
    'PATH' => [::File.dirname(bundler_bin), ENV['PATH']].join(':')
  user 'vagrant'
end

execute 'bundler package' do
  cwd node['bach']['repository']['repo_directory']
  command "#{bundler_bin} package"
  # restore system PKG_CONFIG_PATH so mkmf::pkg_config()
  # can find system libraries
  environment \
    'PKG_CONFIG_PATH' => %w(/usr/lib/pkgconfig
                            /usr/lib/x86_64-linux-gnu/pkgconfig
                            /usr/share/pkgconfig).join(':'),
    'PATH' => [::File.dirname(bundler_bin), ENV['PATH']].join(':')
  user 'vagrant'
end

# if we make the cache directory before running bundle we get an error
# that we can't open a (non-existant) gem in the directory
directory gems_dir do
  owner 'vagrant'
  mode 0555
end

old_gems_dir = "#{bins_dir}/gems"

directory old_gems_dir do
  action :delete
  recursive true
  only_if { File.directory?(old_gems_dir) }
end

link old_gems_dir do
  to "#{gems_dir}"
end

execute 'gem-generate-index' do
  command "#{gem_binary} generate_index"
  cwd bins_dir
  only_if do
    index_path = "#{bins_dir}/specs.4.8.gz"

    # If the index is missing, regenerate.
    # If any gems are newer than the index, regenerate.
    if !File.exist?(index_path)
      true
    else
      gem_mtimes = Dir.glob("#{gems_dir}/*.gem").map do |ff|
        File.mtime(ff)
      end

      gem_mtimes.max > File.mtime(index_path)
    end
  end
end
