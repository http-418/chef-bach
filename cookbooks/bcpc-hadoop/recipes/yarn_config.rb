# yarn_env_values is made up of the env.sh settings from the node
# object: wrapper cookbook attributes, environment overrides, etc
yarn_env_values = node[:bcpc][:hadoop][:yarn][:env_sh]

# yarn_env_generated_values is a hash of values generated here in this
# recipe.  These values will be merged with the yarn_env-Values
yarn_env_generated_values = {}

if(node.run_list.expand(node.chef_environment).recipes
       .include?("bach_spark::default"))
  yarn_env_generated_values[:YARN_USER_CLASSPATH] =
    '/usr/spark/current/lib/spark-yarn-shuffle.jar'
end

complete_yarn_env_hash =
  yarn_env_generated_values.merge(yarn_env_values)

template '/etc/hadoop/conf/yarn-env.sh' do
  source 'generic_env.sh.erb'
  mode 0555
  variables(:options => complete_yarn_env_hash)
end  

yarn_site_values = node[:bcpc][:hadoop][:yarn][:site_xml]
yarn_site_generated_values = {}

complete_yarn_site_hash =
  yarn_site_generated_values.merge(yarn_site_values)

template "/etc/hadoop/conf/yarn-site.xml" do
  source "hdp_yarn-site.xml.erb"
  mode 0644
  variables(:nn_hosts => node[:bcpc][:hadoop][:nn_hosts],
            :zk_hosts => node[:bcpc][:hadoop][:zookeeper][:servers],
            :jn_hosts => node[:bcpc][:hadoop][:jn_hosts],
            :rm_hosts => node[:bcpc][:hadoop][:rm_hosts],
            :dn_hosts => node[:bcpc][:hadoop][:dn_hosts],
            :hs_hosts => node[:bcpc][:hadoop][:hs_hosts],
            :mounts => node[:bcpc][:hadoop][:mounts])
end


file "/etc/hadoop/conf/yarn.exclude" do
  mode 0644
  content ''
end
