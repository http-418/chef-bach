#
# Cookbook Name:: bcpc
# Recipe:: powerdns
#
# Copyright 2016, Bloomberg Finance L.P.
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

make_config('mysql-pdns-user', "pdns")

mysql_pdns_password = get_config("mysql-pdns-password")
if mysql_pdns_password.nil?
  mysql_pdns_password = secure_password
end

pdns_admins = (get_head_node_names + [get_bootstrap]).join(',')

chef_vault_secret 'mysql-pdns' do
  #
  # For some reason, we are compelled to specify a provider.
  # This will probably break if we ever move to chef-vault cookbook 2.x
  #
  provider ChefVaultCookbook::Provider::ChefVaultSecret

  data_bag 'os'
  raw_data({ 'password' => mysql_pdns_password })
  admins pdns_admins
  search '*:*'
  action :nothing
end.run_action(:create_if_missing)

subnet = node[:bcpc][:management][:subnet]
raise "Did not get a subnet" if not subnet

%w{pdns-server pdns-backend-mysql}.each do |pkg|
    package pkg do
        action :upgrade
    end
end

template "/etc/powerdns/pdns.conf" do
    source "pdns.conf.erb"
    owner "root"
    group "root"
    mode 00600
    notifies :restart, "service[pdns]", :delayed
end

ruby_block "powerdns-database-creation" do
    block do
        mysql_root_password = get_config!('password','mysql-root','os')
        system "mysql -uroot -p#{ mysql_root_password } -e 'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \"#{node[:bcpc][:pdns_dbname]}\"' | grep -q \"#{node[:bcpc][:pdns_dbname]}\""
        if not $?.success? then
            %x[ mysql -uroot -p#{ mysql_root_password } -e "CREATE DATABASE #{node[:bcpc][:pdns_dbname]} CHARACTER SET utf8 COLLATE utf8_general_ci;"
                mysql -uroot -p#{ mysql_root_password } -e "GRANT ALL ON #{node[:bcpc][:pdns_dbname]}.* TO '#{get_config('mysql-pdns-user')}'@'%' IDENTIFIED BY '#{get_config!('password','mysql-pdns','os')}';"
                mysql -uroot -p#{ mysql_root_password } -e "GRANT ALL ON #{node[:bcpc][:pdns_dbname]}.* TO '#{get_config('mysql-pdns-user')}'@'localhost' IDENTIFIED BY '#{get_config!('password','mysql-pdns','os')}';"
                mysql -uroot -p#{ mysql_root_password } -e "FLUSH PRIVILEGES;"
            ]
            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references
        end
    end
end

ruby_block "powerdns-table-domains" do
    block do
        mysql_root_password = get_config!('password','mysql-root','os')

        reverse_dns_zone = node['bcpc']['networks'][subnet]['floating']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['networks'][subnet]['floating']['cidr'])

        system "mysql -uroot -p#{ mysql_root_password } -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = \"#{node[:bcpc][:pdns_dbname]}\" AND TABLE_NAME=\"domains_static\"' | grep -q \"domains_static\""
        if not $?.success? then
            %x[ mysql -uroot -p#{ mysql_root_password } #{node[:bcpc][:pdns_dbname]} <<-EOH
                CREATE TABLE IF NOT EXISTS domains_static (
                    id INT auto_increment,
                    name VARCHAR(255) NOT NULL,
                    master VARCHAR(128) DEFAULT NULL,
                    last_check INT DEFAULT NULL,
                    type VARCHAR(6) NOT NULL,
                    notified_serial INT DEFAULT NULL,
                    account VARCHAR(40) DEFAULT NULL,
                    primary key (id)
                );
                INSERT INTO domains_static (name, type) values ('#{node[:bcpc][:domain_name]}', 'NATIVE');
                INSERT INTO domains_static (name, type) values ('#{reverse_dns_zone}', 'NATIVE');
                CREATE UNIQUE INDEX dom_name_index ON domains_static(name);
            ]
            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references
        end
    end
end

ruby_block "powerdns-table-records" do
    block do
        mysql_root_password = get_config!('password','mysql-root','os')

        reverse_dns_zone = node['bcpc']['networks'][subnet]['floating']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['networks'][subnet]['floating']['cidr'])

        system "mysql -uroot -p#{ mysql_root_password } -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = \"#{node[:bcpc][:pdns_dbname]}\" AND TABLE_NAME=\"records_static\"' | grep -q \"records_static\""
        if not $?.success? then
            %x[ mysql -uroot -p#{ mysql_root_password } #{node[:bcpc][:pdns_dbname]} <<-EOH
                    CREATE TABLE IF NOT EXISTS records_static (
                        id INT auto_increment,
                        domain_id INT DEFAULT NULL,
                        name VARCHAR(255) DEFAULT NULL,
                        type VARCHAR(6) DEFAULT NULL,
                        content VARCHAR(255) DEFAULT NULL,
                        ttl INT DEFAULT NULL,
                        prio INT DEFAULT NULL,
                        change_date INT DEFAULT NULL,
                        primary key(id)
                    );
                    INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains_static WHERE name='#{node[:bcpc][:domain_name]}'),'#{node[:bcpc][:domain_name]}','localhost root@#{node[:bcpc][:domain_name]} 1','SOA',300,NULL);
                    INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains_static WHERE name='#{node[:bcpc][:domain_name]}'),'#{node[:bcpc][:domain_name]}','#{node[:bcpc]['networks'][subnet][:management][:vip]}','NS',300,NULL);
                    INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains_static WHERE name='#{node[:bcpc][:domain_name]}'),'#{node[:bcpc][:domain_name]}','#{node[:bcpc]['networks'][subnet][:management][:vip]}','A',300,NULL);

                    INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains_static WHERE name='#{reverse_dns_zone}'),'#{reverse_dns_zone}', '#{reverse_dns_zone} root@#{node[:bcpc][:domain_name]} 1','SOA',300,NULL);
                    INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains_static WHERE name='#{reverse_dns_zone}'),'#{reverse_dns_zone}','#{node[:bcpc]['networks'][subnet][:management][:vip]}','NS',300,NULL);

                    CREATE INDEX rec_name_index ON records_static(name);
                    CREATE INDEX nametype_index ON records_static(name,type);
                    CREATE INDEX domain_id ON records_static(domain_id);
            ]
            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references
        end
    end
end

ruby_block "powerdns-function-ip4_to_ptr_name" do
    block do
        mysql_root_password = get_config!('password','mysql-root','os')
        system "mysql -uroot -p#{ mysql_root_password } -e 'SELECT name FROM mysql.proc WHERE name = \"ip4_to_ptr_name\" AND db = \"#{node[:bcpc][:pdns_dbname]}\";' \"#{node[:bcpc][:pdns_dbname]}\" | grep -q \"ip4_to_ptr_name\""
        if not $?.success? then
            %x[ mysql -uroot -p#{ mysql_root_password } #{node[:bcpc][:pdns_dbname]} <<-EOH
                delimiter //
                CREATE FUNCTION ip4_to_ptr_name(ip4 VARCHAR(64) CHARACTER SET latin1) RETURNS VARCHAR(64)
                COMMENT 'Returns the reversed IP with .in-addr.arpa appended, suitable for use in the name column of PTR records.'
                DETERMINISTIC
                BEGIN

                return concat_ws( '.',  SUBSTRING_INDEX( SUBSTRING_INDEX(ip4, '.', 4), '.', -1),
                                        SUBSTRING_INDEX( SUBSTRING_INDEX(ip4, '.', 3), '.', -1),
                                        SUBSTRING_INDEX( SUBSTRING_INDEX(ip4, '.', 2), '.', -1),
                                        SUBSTRING_INDEX( SUBSTRING_INDEX(ip4, '.', 1), '.', -1), 'in-addr.arpa');

                END//
            ]
            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references
        end
    end
end

ruby_block "powerdns-table-domains-view" do
    block do
        mysql_root_password = get_config!('password','mysql-root','os')
        system "mysql -uroot -p#{ mysql_root_password } -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = \"#{node[:bcpc][:pdns_dbname]}\" AND TABLE_NAME=\"domains\"' | grep -q \"domains\""
        if not $?.success? then
            %x[ mysql -uroot -p#{ mysql_root_password } #{node[:bcpc][:pdns_dbname]} <<-EOH
                CREATE OR REPLACE VIEW domains AS
                    SELECT id,name,master,last_check,type,notified_serial,account FROM domains_static;
            ]
            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references
        end
    end
end

ruby_block "powerdns-table-records_forward-view" do
    block do
        mysql_root_password = get_config!('password','mysql-root','os')
        system "mysql -uroot -p#{ mysql_root_password } -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = \"#{node[:bcpc][:pdns_dbname]}\" AND TABLE_NAME=\"records_forward\"' | grep -q \"records_forward\""
        if not $?.success? then
            %x[ mysql -uroot -p#{ mysql_root_password } #{node[:bcpc][:pdns_dbname]} <<-EOH
                CREATE OR REPLACE VIEW records_forward AS
                    SELECT id,domain_id,name,type,content,ttl,prio,change_date FROM records_static;
            ]
            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references
        end
    end
end

ruby_block "powerdns-table-records_reverse-view" do
    block do
        mysql_root_password = get_config!('password','mysql-root','os')

        reverse_dns_zone = node['bcpc']['networks'][subnet]['floating']['reverse_dns_zone'] || calc_reverse_dns_zone(node['bcpc']['networks'][subnet]['floating']['cidr'])

        system "mysql -uroot -p#{ mysql_root_password } -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = \"#{node[:bcpc][:pdns_dbname]}\" AND TABLE_NAME=\"records_reverse\"' | grep -q \"records_reverse\""
        if not $?.success? then

            %x[ mysql -uroot -p#{ mysql_root_password } #{node[:bcpc][:pdns_dbname]} <<-EOH
                create or replace view records_reverse as
                select r.id * -1 as id, d.id as domain_id,
                      ip4_to_ptr_name(r.content) as name,
                      'PTR' as type, r.name as content, r.ttl, r.prio, r.change_date
                from records_forward r, domains d
                where r.type='A'
                  and d.name = '#{reverse_dns_zone}'
                  and ip4_to_ptr_name(r.content) like '%.#{reverse_dns_zone}';

            ]
            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references

        end
    end
end


ruby_block "powerdns-table-records-view" do

    block do
        mysql_root_password = get_config!('password','mysql-root','os')
        system "mysql -uroot -p#{ mysql_root_password } -e 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = \"#{node[:bcpc][:pdns_dbname]}\" AND TABLE_NAME=\"records\"' | grep -q \"records\""
        if not $?.success? then

            %x[ mysql -uroot -p#{ mysql_root_password } #{node[:bcpc][:pdns_dbname]} <<-EOH
              create or replace view records as
                select id, domain_id, name, type, content, ttl, prio, change_date from records_forward
                union all
                select id, domain_id, name, type, content, ttl, prio, change_date from records_reverse;
            ]

            self.notifies :restart, "service[pdns]", :delayed
            self.resolve_notification_references
        end

    end

end

get_all_nodes.each do |server|
    ruby_block "create-dns-entry-#{server['hostname']}" do
        block do
            mysql_root_password = get_config!('password','mysql-root','os')
            # check if we have a float address
            float_host_A_record=""
            if server['bcpc']['management']['ip'] != server['bcpc']['floating']['ip'] then
                float_host_A_record="INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='#{node[:bcpc][:domain_name]}'),'#{float_host(server['hostname'])}.#{node[:bcpc][:domain_name]}','#{server['bcpc']['floating']['ip']}','A',300,NULL);"
            end

            # check if we have a storage address
            storage_host_A_record=""
            if server['bcpc']['management']['ip'] != server['bcpc']['storage']['ip'] then
                storage_host_A_record="INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='#{node[:bcpc][:domain_name]}'),'#{storage_host(server['hostname'])}.#{node[:bcpc][:domain_name]}','#{server['bcpc']['storage']['ip']}','A',300,NULL);"
            end

            system "mysql -uroot -p#{ mysql_root_password } #{node[:bcpc][:pdns_dbname]} -e 'SELECT name FROM records_static' | grep -q \"#{server['hostname']}.#{node[:bcpc][:domain_name]}\""
            if not $?.success? then
                %x[ mysql -uroot -p#{ mysql_root_password } #{node[:bcpc][:pdns_dbname]} <<-EOH
                        INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='#{node[:bcpc][:domain_name]}'),'#{server['hostname']}.#{node[:bcpc][:domain_name]}','#{server['bcpc']['management']['ip']}','A',300,NULL);
                        #{storage_host_A_record}
                        #{float_host_A_record}
                ]
            end
        end
    end if server.has_key?('hostname')
end

%w{graphite zabbix}.each do |static|
    ruby_block "create-management-dns-entry-#{static}" do
        block do
            mysql_root_password = get_config!('password','mysql-root','os')
            if get_nodes_for(static).length >= 1 then
                system "mysql -uroot -p#{ mysql_root_password } #{node[:bcpc][:pdns_dbname]} -e 'SELECT name FROM records_static' | grep -q \"#{static}.#{node[:bcpc][:domain_name]}\""
                if not $?.success? then
                    %x[ mysql -uroot -p#{ mysql_root_password } #{node[:bcpc][:pdns_dbname]} <<-EOH
                            INSERT INTO records_static (domain_id, name, content, type, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='#{node[:bcpc][:domain_name]}'),'#{static}.#{node[:bcpc][:domain_name]}','#{node[:bcpc]['networks'][subnet][:management][:vip]}','A',300,NULL);
                    ]
                end
            end
        end
    end
end

template "/etc/powerdns/pdns.d/pdns.local.gmysql" do
    source "pdns.local.gmysql.erb"
    owner "pdns"
    group "root"
    mode 00640
    notifies :restart, "service[pdns]", :immediately
end

service "pdns" do
    action [ :enable, :start ]
end
