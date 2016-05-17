# vim: tabstop=2:shiftwidth=2:softtabstop=2
default['bcpc']['hadoop']['hbase'].tap do |hbase|
  hbase['root_dir'] = "#{node['bcpc']['hadoop']['hdfs_url']}/hbase"
  hbase['bulkload_staging_dir'] = '/tmp/hbase'
  hbase['repl']['enabled'] = false
  hbase['repl']['peer_id'] = node.chef_environment.gsub('-', '_')
  hbase['repl']['target'] = ''
  hbase['superusers'] = ['hbase']
  hbase['cluster']['distributed'] = true
  hbase['defaults']['for']['version']['skip'] = true
  hbase['dfs']['client']['read']['shortcircuit']['buffer']['size'] = 131_072
  hbase['regionserver']['handler']['count'] = 128
  # Interval in milli seconds when HBase major compaction need to be
  # run. Disabled by default
  hbase['major_compact']['time'] = 0
  hbase['bucketcache']['enabled'] = false
  hbase['blockcache']['size'] = 0.4
  hbase['bucketcache']['size'] = 1434
  hbase['bucketcache']['ioengine'] = 'offheap'
  hbase['bucketcache']['combinedcache']['percentage'] = 0.71
  hbase['shortcircuit']['read'] = false
  hbase['region']['replication']['enabled'] = false
  hbase['region']['replica']['storefile']['refresh']['memstore']['multiplier'] =
    4
  hbase['region']['replica']['wait']['for']['primary']['flush'] = true
  hbase['hregion']['memstore']['block']['multiplier'] = 8
  hbase['ipc']['client']['specificthreadforwriting'] = true
  hbase['client']['primarycalltimeout']['get'] = 100_000
  hbase['client']['primarycalltimeout']['multiget'] = 100_000
  hbase['meta']['replica']['count'] = 3
  hbase['ipc']['warn']['response']['time'] = 250
  hbase['ipc']['warn']['response']['size'] = 1_048_576
end

default['bcpc']['hadoop']['hbase_master']['hfilecleaner']['ttl'] = 3_600_000
default['bcpc']['hadoop']['hbase_master']['jmx']['port'] = 10_101
default['bcpc']['hadoop']['hbase_rs']['coprocessor']['abortonerror'] = true
default['bcpc']['hadoop']['hbase_rs']['jmx']['port'] = 10_102
default['bcpc']['hadoop']['hbase_rs']['xmn']['size'] = 256
default['bcpc']['hadoop']['hbase_rs']['xms']['size'] = 1024
default['bcpc']['hadoop']['hbase_rs']['xmx']['size'] = 1024
default['bcpc']['hadoop']['hbase_rs']['mx_dir_mem']['size'] = 256
default['bcpc']['hadoop']['hbase_rs']['hdfs_dir_mem']['size'] = 128
default['bcpc']['hadoop']['hbase_rs']['gc_thread']['cpu_ratio'] = 0.4
default['bcpc']['hadoop']['hbase_rs']['memstore']['upperlimit'] = 0.4
default['bcpc']['hadoop']['hbase_rs']['memstore']['lowerlimit'] = 0.2
default['bcpc']['hadoop']['hbase_rs']['storefile']['refresh']['all'] = false
default['bcpc']['hadoop']['hbase_rs']['storefile']['refresh']['period'] = 30_000
default['bcpc']['hadoop']['hbase_rs']['cmsinitiatingoccupancyfraction'] = 70
default['bcpc']['hadoop']['hbase_rs']['PretenureSizeThreshold'] = '1m'

# Apache Phoenix related attributes.
default['bcpc']['hadoop']['phoenix']['tracing']['enabled'] = false

xmx = node['bcpc']['hadoop']['hbase_rs']['xmx']['size']
blockcache = node['bcpc']['hadoop']['hbase']['blockcache']['size']
mx_dir_mem = node['bcpc']['hadoop']['hbase_rs']['mx_dir_mem']['size']
hdfs_dir_mem = node['bcpc']['hadoop']['hbase_rs']['hdfs_dir_mem']['size']

bucketcache_size =
  (((xmx * blockcache) + mx_dir_mem) - hdfs_dir_mem).floor

bucketcache_combinedcache_percent =
  bucketcache_size.to_f / ((hdfs_dir_mem + mx_dir_mem) - hdfs_dir_mem)

#
# These will become key/value pairs in 'hbase_site.xml'
#
# Additional properties are defined at runtime in the
# bcpc-hadoop::hbase_config recipe.
#
management_subnet = node['bcpc']['management']['subnet']
management_interface =
  node['bcpc']['networks'][management_subnet]['floating']['interface']

default['bcpc']['hadoop']['hbase']['site_xml'].tap do |site_xml|
  site_xml['hbase.rootdir'] =
    node['bcpc']['hadoop']['hbase']['root_dir'].to_s

  site_xml['hbase.bulkload.staging.dir'] =
    node['bcpc']['hadoop']['hbase']['bulkload_staging_dir'].to_s

  site_xml['hbase.cluster.distributed'] =
    node['bcpc']['hadoop']['hbase']['cluster']['distributed'].to_s

  site_xml['hbase.hregion.majorcompaction'] =
    node['bcpc']['hadoop']['hbase']['major_compact']['time'].to_s

  site_xml['hbase.regionserver.dns.interface'] =
    management_interface

  site_xml['hbase.master.dns.interface'] =
    management_interface

  site_xml['hbase.regionserver.ipc.address'] =
    node['bcpc']['floating']['ip'].to_s

  site_xml['hbase.master.ipc.address'] =
    node['bcpc']['floating']['ip'].to_s

  site_xml['hbase.defaults.for.version.skip'] =
    node['bcpc']['hadoop']['hbase']['defaults']['for']['version']['skip'].to_s

  site_xml['hbase.regionserver.wal.codec'] =
    'org.apache.hadoop.hbase.regionserver.wal.IndexedWALEditCodec'

  site_xml['hbase.region.server.rpc.scheduler.factory.class'] =
    'org.apache.hadoop.hbase.ipc.PhoenixRpcSchedulerFactory'

  site_xml['hbase.rpc.controllerfactory.class'] =
    'org.apache.hadoop.hbase.ipc.controller.ServerRpcControllerFactory'

  site_xml['dfs.client.read.shortcircuit'] =
    node['bcpc']['hadoop']['hbase']['shortcircuit']['read'].to_s

  if node['bcpc']['hadoop']['hbase']['shortcircuit']['read']
    site_xml['dfs.domain.socket.path'] =  '/var/run/hadoop-hdfs/dn._PORT'

    hbase = node['bcpc']['hadoop']['hbase']

    site_xml['dfs.client.read.shortcircuit.buffer.size'] =
      hbase['dfs']['client']['read']['shortcircuit']['buffer']['size'].to_s
  end

  site_xml['hbase.regionserver.handler.count'] =
    node['bcpc']['hadoop']['hbase']['regionserver']['handler']['count'].to_s

  site_xml['hbase.ipc.warn.response.time'] =
    node['bcpc']['hadoop']['hbase']['ipc']['warn']['response']['time'].to_s

  site_xml['hbase.ipc.warn.response.size'] =
    node['bcpc']['hadoop']['hbase']['ipc']['warn']['response']['size'].to_s

  site_xml['hbase.ipc.server.tcpnodelay'] = 'true'

  if node['bcpc']['hadoop']['hbase']['bucketcache']['enabled']
    site_xml['hbase.regionserver.global.memstore.upperLimit'] =
      node['bcpc']['hadoop']['hbase_rs']['memstore']['upperlimit'].to_s

    site_xml['hfile.block.cache.size'] =
      node['bcpc']['hadoop']['hbase']['blockcache']['size'].to_s

    site_xml['hbase.bucketcache.size'] = bucketcache_size

    site_xml['hbase.bucketcache.ioengine '] =
      node['bcpc']['hadoop']['hbase']['bucketcache']['ioengine']

    site_xml['hbase.bucketcache.percentage.in.combinedcache'] =
      bucketcache_combinedcache_percent
  end
  if node['bcpc']['hadoop']['hbase']['region']['replication']['enabled']
    site_xml['hbase.regionserver.storefile.refresh.period'] =
      node['bcpc']['hadoop']['hbase_rs']['storefile']['refresh']['period']

    site_xml['hbase.region.replica.replication.enabled'] =
      node['bcpc']['hadoop']['hbase']['region']['replication']['enabled']

    site_xml['hbase.master.hfilecleaner.ttl'] =
      node['bcpc']['hadoop']['hbase_master']['hfilecleaner']['ttl']

    site_xml['hbase.meta.replica.count'] =
      node['bcpc']['hadoop']['hbase']['meta']['replica']['count']

    site_xml['hbase.regionserver.storefile.refresh.all'] =
      node['bcpc']['hadoop']['hbase_rs']['storefile']['refresh']['all']

    replica = node['bcpc']['hadoop']['hbase']['region']['replica']

    site_xml['hbase.region.replica.storefile.refresh.memstore.multiplier'] =
      replica['storefile']['refresh']['memstore']['multiplier']

    site_xml['hbase.region.replica.wait.for.primary.flush'] =
      replica['wait']['for']['primary']['flush']

    site_xml['hbase.regionserver.global.memstore.lowerLimit'] =
      node['bcpc']['hadoop']['hbase_rs']['memstore']['lowerlimit']

    hbase = node['bcpc']['hadoop']['hbase']

    site_xml['hbase.hregion.memstore.block.multiplier'] =
      hbase['hregion']['memstore']['block']['multiplier']

    site_xml['hbase.ipc.client.specificThreadForWriting'] =
      hbase['ipc']['client']['specificthreadforwriting']

    site_xml['hbase.client.primaryCallTimeout.get'] =
      hbase['client']['primarycalltimeout']['get']

    site_xml['hbase.client.primaryCallTimeout.multiget'] =
      hbase['client']['primarycalltimeout']['multiget']
  end

  site_xml['hbase.replication'] = 'true'

  site_xml['hbase.coprocessor.abortonerror'] =
    node['bcpc']['hadoop']['hbase_rs']['coprocessor']['abortonerror']
end
