#
# Cookbook Name:: bcpc
# Recipe:: powerdns
#
# Copyright 2013, Bloomberg Finance L.P.
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

make_bcpc_config('mysql-pdns-user', "pdns")
make_bcpc_config('mysql-pdns-password', secure_password)

bootstrap = get_bootstrap
results = get_all_nodes.map!{ |x| x['fqdn'] }.join(",")
nodes = results == "" ? node['fqdn'] : results

chef_vault_secret "mysql-pdns" do
  data_bag 'os'
  raw_data({ 'password' => get_bcpc_config!('mysql-pdns-password')} )
  admins "#{ nodes },#{ bootstrap }"
  search '*:*'
  action :nothing
end.run_action(:create_if_missing)

node.set['pdns']['authoritative']['package']['backends'] = ['gmysql']
node.set['pdns']['authoritative']['config']['disable_axfr'] = false

node.set['pdns']['authoritative']['config'].tap do |config|
  config['launch'] = 'gmysql'
  config['recursor'] = node[:bcpc][:dns_servers][0]
end

node.set['pdns']['authoritative']['gmysql'].tap do |config|
  config['gmysql-host'] = node[:bcpc][:management][:vip]
  config['gmysql-port'] = 3306
  config['gmysql-user'] = get_bcpc_config!('mysql-pdns-user')
  config['gmysql-password'] = get_bcpc_config!('mysql-pdns-password')
  config['gmysql-dbname'] = node['bcpc']['pdns_dbname']
  config['gmysql-dnssec'] = 'yes'
end

package 'libmysqlclient-dev'

chef_gem 'mysql2' do
  compile_time false
end

mysql_connection_info = 
{
 :host => node['pdns']['authoritative']['config']['gmysql-host'],
 :username => 'root',
 :password => get_bcpc_config!('mysql-root-password')
}

mysql_database node['bcpc']['pdns_dbname'] do
  connection mysql_connection_info
  notifies :run, 'execute[install-pdns-schema]', :immediately
end

mysql_database_user get_bcpc_config!('mysql-pdns-user') do
  connection mysql_connection_info
  password get_bcpc_config!('mysql-pdns-password')
  action :create
  notifies :reload, 'service[pdns]'
end

mysql_database_user get_bcpc_config!('mysql-pdns-user') do
  connection mysql_connection_info
  database_name node['bcpc']['pdns_dbname']
  host '%'
  privileges [:all]
  action :grant
  notifies :reload, 'service[pdns]'
end

include_recipe 'pdns::authoritative_package'

#
# This schema file works great when installed via the mysql CLI, but
# it fails when Ruby reads it and feeds via a query resource.  This
# smells like an escaping problem.
#
# For now, the query resource has been replaced with an 'execute'
# resource that invokes the mysql CLI.
#
schema_path = '/usr/share/dbconfig-common/data/pdns-backend-mysql/install/mysql'

mysql_command_string =
  "/usr/bin/mysql -u root " + 
  "--host=#{node['pdns']['authoritative']['config']['gmysql-host']} " +
  "--password='#{get_bcpc_config!('mysql-root-password')}' pdns"

execute 'install-pdns-schema' do
  command "cat #{schema_path} | " +
    "perl -nle 's/type=Inno/engine=Inno/g; print' | " +
    mysql_command_string

  not_if {
    c = Mixlib::ShellOut.new('echo "select id from domains limit 1;" | ' +
                             mysql_command_string)
    c.run_command
    c.status.success?
  }

  sensitive true
      
  notifies :reload, 'service[pdns]'
end


reverse_dns_zone = node['bcpc']['floating']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['floating']['cidr'])

Chef::Log.warn("Reverse DNS zone: #{reverse_dns_zone}")

pdns_domain node[:bcpc][:domain_name] do
  soa_ip node[:bcpc][:floating][:vip]
end

get_all_nodes.each do |server|
    ruby_block "create-dns-entry-#{server['hostname']}" do
        block do
            mysql_root_password = get_config!('password','mysql-root','os')
            # check if we have a float address
            if server['bcpc']['management']['ip'] != server['bcpc']['floating']['ip'] then
              r = Chef::Resource::PdnsRecord.new(float_host(server['hostname']), 
                                                 run_context)
              r.domain(node[:bcpc][:domain_name])
              r.content(server[:bcpc][:floating][:ip])
              r.type('A')
              r.ttl(300)
              r.run_action(:create)
            end

            # check if we have a storage address
            if server['bcpc']['management']['ip'] != server['bcpc']['storage']['ip'] then
              r = Chef::Resource::PdnsRecord.new(storage_host(server['hostname']), 
                                                 run_context)
              r.domain(node[:bcpc][:domain_name])
              r.content(server[:bcpc][:storage][:ip])
              r.type('A')
              r.ttl(300)
              r.run_action(:create)
            end

            # add a record for the management IP
            r = Chef::Resource::PdnsRecord.new(server['hostname'], 
                                               run_context)
            r.domain(node[:bcpc][:domain_name])
            r.content(server[:bcpc][:management][:ip])
            r.type('A')
            r.ttl(300)
            r.run_action(:create)
        end
    end
end

# %w{openstack graphite zabbix}.each do |static|
#     ruby_block "create-management-dns-entry-#{static}" do
#         block do
#             if get_nodes_for(static).length >= 1 then
#                 system "mysql -uroot -p#{get_bcpc_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} -e 'SELECT name FROM records_static' | grep -q \"#{static}.#{node[:bcpc][:domain_name]}\""
#                 if not $?.success? then
#                     %x[ mysql -uroot -p#{get_bcpc_config('mysql-root-password')} #{node[:bcpc][:pdns_dbname]} <<-EOH
#                             INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='#{node[:bcpc][:domain_name]}'),'#{static}.#{node[:bcpc][:domain_name]}','#{node[:bcpc][:management][:vip]}','A',300,NULL);
#                     ]
#                 end
#             end
#         end
#     end
# end
