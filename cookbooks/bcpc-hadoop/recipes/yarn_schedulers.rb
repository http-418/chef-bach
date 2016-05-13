hadoop_templates =
  %w{
   fair-scheduler.xml
  }

hadoop_templates.each do |t|
   template "/etc/hadoop/conf/#{t}" do
     source "hdp_#{t}.erb"
     mode 0644
     variables(:nn_hosts => node[:bcpc][:hadoop][:nn_hosts],
               :zk_hosts => node[:bcpc][:hadoop][:zookeeper][:servers],
               :jn_hosts => node[:bcpc][:hadoop][:jn_hosts],
               :rm_hosts => node[:bcpc][:hadoop][:rm_hosts],
               :dn_hosts => node[:bcpc][:hadoop][:dn_hosts],
               :hs_hosts => node[:bcpc][:hadoop][:hs_hosts],
               :mounts => node[:bcpc][:hadoop][:mounts])
   end
end

template "/etc/hadoop/conf/capacity-scheduler.xml" do
  source "generic_site.xml.erb"
  mode 0644
  variables(:options =>
            node[:bcpc][:hadoop][:yarn][:scheduler][:capacity][:xml])
end

template '/etc/hadoop/conf/fair-scheduler.fresh.xml' do
  source 'yarn/fair-scheduler.xml.erb'
  owner 'root'
  group 'root'
  mode 0644
  variables(lazy{{
              :queues =>
                run_context.resource_collection.select{ |r| r.class ==
                  Chef::Resource::BcpcHadoopFairSchedulerQueue }
                 }})
end

yarn = node[:bcpc][:hadoop][:yarn]
minimum_cores = yarn['scheduler']['fair']['min-vcores']
minimum_ram = yarn['scheduler']['minimum-allocation-mb'] * minimum_cores

bcpc_hadoop_fair_scheduler_queue 'default' do
  weight 1.0
  fair_share_preemption_timeout yarn['fairsharepreemptiontimeout']
  min_resources "#{minimum_ram} mb,#{minimum_cores}vcores"
  type 'parent'
end

bcpc_hadoop_fair_scheduler_queue 'data_license' do
  scheduling_policy 'fifo'
  acl_administer_apps = 'odsuser,dluser'
  weight 2.0
  max_running_apps 3
  min_resources '5000 mb,5vcores'
  max_resources '256000 mb,200vcores'
end
