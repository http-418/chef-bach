#
# Cookbook Name:: bcpc_kafka
# Recipe: Kafka
#
# Copyright 2017, Bloomberg Finance L.P.
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

#
# We need node search to set a reasonable value for num.partitions, so
# the value from the attributes file must be overriden.
#
# The value is saved in the node object so that the default partition count
# can only go up, not down.
#
node.normal[:kafka][:broker][:num][:partitions] =
  [
    node[:kafka][:broker][:num][:partitions],
    search(:node, 'role:BCPC-Kafka-Head-Server').count,
    3
  ].max

package 'netcat-openbsd' do
  action :upgrade
end

#
# In a standalone Kafka cluster, get_head_nodes will return the
# Zookeeper servers.
#
# In a mixed Hadoop/Kafka cluster, the regular Hadoop head nodes will
# be running Zookeeper.
#
# See cookbooks/bcpc/libraries/utils.rb for details.
#
node.default[:kafka][:broker][:zookeeper][:connect] = get_head_nodes.map do |nn|
  float_host(nn[:fqdn])
end.sort

#
# This is a list of paths for the kafka logs (actual topic data)
#
# The path for human-readable logs (information about what kafka is
# doing) is found in node[:kafka][:log_dir]
#
# Unfortunately this cannot be a lazy block (Chef::DelayedEvaluator)
# because the upstream kafka cookbook expects to examine log directory
# values at compile time.
#
# As a result, the first chef run will configure Kafka to use only one
# data volume, the fallback path of /disk/0.
#
data_volumes = Dir.glob('/disk/*').select { |pp| ::File.directory?(pp) }
data_volumes << '/disk/0' if data_volumes.empty?

node.default[:kafka][:broker][:log][:dirs] = data_volumes.map do |dd|
  File.join(dd, 'kafka', 'data')
end

include_recipe 'bcpc_kafka::default'
include_recipe 'kafka::default'

user_ulimit 'kafka' do
  filehandle_limit 32_768
  notifies :restart, 'service[kafka-broker]', :immediately
end

ruby_block 'kafkaup' do
  block do
    zk_path =
      "/brokers/ids/#{node[:kafka][:broker][:broker_id]}"

    zk_hosts =
      node[:kafka][:broker][:zookeeper][:connect]

    zk_connection_string =
      zk_hosts.map { |zkh| "#{zkh}:2181" }.join(',')

    Chef::Log.info("Zookeeper hosts are #{zk_connection_string}")

    max_time = 19
    max_time.times do |ii|
      if znode_exists?(zk_path, zk_connection_string)
        Chef::Log.info("Kafka broker at znode #{zk_path} is marked up.")
        break
      else
        Chef::Log.info("Kafka broker at znode #{zk_path} is marked " \
                       "down. (#{ii})")
      end
      sleep(1)
    end

    unless znode_exists?(zk_path, zk_connection_string)
      raise "Kafka is reported down for more than #{max_time} seconds"
    end
  end
end

include_recipe 'bcpc::diamond'
include_recipe 'bcpc_jmxtrans'
