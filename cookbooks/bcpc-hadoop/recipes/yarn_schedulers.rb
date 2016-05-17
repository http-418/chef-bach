template '/etc/hadoop/conf/capacity-scheduler.xml' do
  source 'generic_site.xml.erb'
  mode 0644
  variables(options:
            node[:bcpc][:hadoop][:yarn][:scheduler][:capacity][:xml])
end

template '/etc/hadoop/conf/fair-scheduler.xml' do
  source 'yarn/fair-scheduler.xml.erb'
  owner 'root'
  group 'root'
  mode 0644
  variables(
             lazy do
               queue_resources = run_context.resource_collection.select do |r|
                 r.class == Chef::Resource::BcpcHadoopFairSchedulerQueue
               end
               { queues: queue_resources }
             end
           )
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
