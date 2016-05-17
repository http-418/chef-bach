###########################################
#
#  Hadoop specific configs
#
#############################################
default['bcpc']['hadoop'].tap do |hadoop|
  hadoop['distribution']['version'] = 'HDP'
  hadoop['distribution']['key'] = 'hortonworks.key'
  hadoop['distribution']['release'] = '2.3.4.0-3485'
  hadoop['distribution']['active_release'] =
    node['bcpc']['hadoop']['distribution']['release']
  # disks to use for Hadoop activities
  # (expected to be an environment or role set variable)
  hadoop['hadoop_home_warn_suppress'] = 1
  hadoop['hadoop_log_dir'] = '/var/log/hadoop-hdfs'
  hadoop['hadoop_mapred_ident_string'] = 'mapred'
  hadoop['hadoop_mapred_log_dir'] = '/var/log/hadoop-mapreduce'
  hadoop['hadoop_secure_dn_log_dir'] = '/var/log/hadoop-hdfs'
  hadoop['hadoop_pid_dir'] = '/var/run/hadoop-hdfs'
  hadoop['hadoop_secure_dn_pid_dir'] = '/var/run/hadoop-hdfs'
  hadoop['hadoop_mapred_pid_dir'] = '/var/run/hadoop-mapreduce'
  hadoop['hadoop_secure_dn_user'] = 'hdfs'
  hadoop['hadoop']['bin']['path'] = '/usr/bin/hadoop'
  hadoop['hadoop']['config']['dir'] = '/etc/hadoop/conf'
  hadoop['hdfs']['HA'] = true
  hadoop['hdfs']['failed_volumes_tolerated'] = 1
  hadoop['hdfs']['dfs_replication_factor'] = 3
  hadoop['hdfs']['dfs_blocksize'] = '128m'
  hadoop['hdfs_url'] = "hdfs://#{node.chef_environment}/"
  hadoop['jmx_enabled'] = true
  hadoop['jute']['maxbuffer'] = 6_291_456
  hadoop['datanode']['xmx']['max_size'] = 4096
  hadoop['datanode']['xmx']['max_ratio'] = 0.25
  hadoop['datanode']['max']['xferthreads'] = 16_384
  hadoop['datanode']['jmx']['port'] = 10_112
  hadoop['datanode']['gc_opts'] =
    [
      '-server',
      '-XX:ParallelGCThreads=4',
      '-XX:+UseParNewGC',
      '-XX:+UseConcMarkSweepGC',
      '-verbose:gc',
      '-XX:+PrintHeapAtGC',
      '-XX:+PrintGCDetails',
      '-XX:+PrintGCTimeStamps',
      '-XX:+PrintGCDateStamps',
      '-Xloggc:/var/log/hadoop-hdfs/gc/gc.log-datanode.log',
      '-XX:+PrintTenuringDistribution',
      '-XX:+UseNUMA',
      '-XX:+PrintGCApplicationStoppedTime',
      '-XX:+UseCompressedOops',
      '-XX:+PrintClassHistogram',
      '-XX:+PrintGCApplicationConcurrentTime'
    ].join(' ')
  hadoop['mapreduce']['framework']['name'] = 'yarn'
  hadoop['namenode']['handler']['count'] = 100
  hadoop['namenode']['gc_opts'] =
    [
      '-server',
      '-XX:ParallelGCThreads=14',
      '-XX:+UseParNewGC',
      '-XX:+UseConcMarkSweepGC',
      '-verbose:gc',
      '-XX:+PrintHeapAtGC',
      '-XX:+PrintGCDetails',
      '-XX:+PrintGCTimeStamps',
      '-XX:+PrintGCDateStamps',
      '-Xloggc:/var/log/hadoop-hdfs/gc/gc.log-namenode.log',
      '-XX:+PrintTenuringDistribution',
      '-XX:+UseNUMA',
      '-XX:+PrintGCApplicationStoppedTime',
      '-XX:+UseCompressedOops',
      '-XX:+PrintClassHistogram',
      '-XX:+PrintGCApplicationConcurrentTime'
    ].join(' ')
  hadoop['namenode']['xmx']['max_size'] = 16_384
  hadoop['namenode']['xmx']['max_ratio'] = 0.25
  hadoop['namenode']['jmx']['port'] = 10_111
  hadoop['namenode']['rpc']['port'] = 8020
  hadoop['namenode']['http']['port'] = 50_070
  hadoop['namenode']['https']['port'] = 50_470
  hadoop['kafka']['jmx']['port'] = 9995
  hadoop['topology']['script'] = 'topology'
  hadoop['topology']['cookbook'] = 'bcpc-hadoop'
  hadoop['yarn']['scheduler']['minimum-allocation-mb'] = 256
  # Setting balancer bandwidth to default value as per hdfs-default.xml
  hadoop['balancer']['bandwidth'] = 1_048_576
  #
  # Attributes for service rolling restart process
  #
  # Number of tries to acquire the lock required to restart the process
  hadoop['restart_lock_acquire']['max_tries'] = 5
  # The path in ZK where the restart locks (znodes)  need to be created
  # The path should exist in ZooKeeper e.g. "/lock" and the default is "/"
  hadoop['restart_lock']['root'] = '/'
  # Sleep time in seconds between tries to acquire the lock for restart
  hadoop['restart_lock_acquire']['sleep_time'] = 2
  # Flag to set whether the restart process was successful or not
  hadoop['datanode']['restart_failed'] = false
end

# These are to cache Chef search results and
# allow hardcoding nodes performing various roles
default[:bcpc][:hadoop][:nn_hosts] = []
default[:bcpc][:hadoop][:jn_hosts] = []
default[:bcpc][:hadoop][:rm_hosts] = []
default[:bcpc][:hadoop][:hs_hosts] = []
default[:bcpc][:hadoop][:dn_hosts] = []
default[:bcpc][:hadoop][:hb_hosts] = []
default[:bcpc][:hadoop][:hive_hosts] = []
default[:bcpc][:hadoop][:oozie_hosts] = []
default[:bcpc][:hadoop][:httpfs_hosts] = []
default[:bcpc][:hadoop][:httpfs_hosts] = []
default[:bcpc][:hadoop][:rs_hosts] = []
default[:bcpc][:hadoop][:mysql_hosts] = []

default['bcpc']['keepalived']['config_template'] = 'keepalived.conf_hadoop'

default['bcpc']['revelytix']['loom_username'] = 'loom'
default['bcpc']['revelytix']['activescan_hdfs_user'] = 'activescan-user'
default['bcpc']['revelytix']['activescan_hdfs_enabled'] = 'true'
default['bcpc']['revelytix']['activescan_table_enabled'] = 'true'
default['bcpc']['revelytix']['hdfs_scan_interval'] = 60
default['bcpc']['revelytix']['hdfs_parse_lines'] = 50
default['bcpc']['revelytix']['hdfs_score_threshold'] = 0.25
default['bcpc']['revelytix']['hdfs_max_buffer_size'] = 8_388_608
default['bcpc']['revelytix']['persist_mode'] = 'hive'
default['bcpc']['revelytix']['dataset_persist_dir'] = 'loom-datasets'
default['bcpc']['revelytix']['temporary_file_dir'] = 'hdfs-default:loom-temp'
default['bcpc']['revelytix']['job_service_thread_pool_size'] = 10
default['bcpc']['revelytix']['security_authentication'] = 'loom'
default['bcpc']['revelytix']['security_enabled'] = 'true'
default['bcpc']['revelytix']['ssl_enabled'] = 'true'
default['bcpc']['revelytix']['ssl_port'] = 8443
default['bcpc']['revelytix']['ssl_keystore'] = 'config/keystore'
default['bcpc']['revelytix']['ssl_key_password'] = ''
default['bcpc']['revelytix']['ssl_trust_store'] = 'config/truststore'
default['bcpc']['revelytix']['ssl_trust_password'] = ''
default['bcpc']['revelytix']['loom_dist_cache'] = 'loom-dist-cache'
default['bcpc']['revelytix']['hive_classloader_blacklist_jars'] =
  'slf4j,log4j,commons-logging'
default['bcpc']['revelytix']['port'] = 8080

# Attributes to store details about (log) files from nodes to be copied
# into a centralized location (currently HDFS).
# E.g. value {'hbase_rs' =>  { 'logfile' => "/path/file_name_of_log_file",
#                              'docopy' => true (or false)
#                             },...
#            }

# It is expected recipes will extend this value as they have files to ship
default['bcpc']['hadoop']['copylog'] = {}

# Attribute to enable/disable the copylog feature
default['bcpc']['hadoop']['copylog_enable'] = true

# File rollup interval in secs for log data copied into HDFS through Flume
default['bcpc']['hadoop']['copylog_rollup_interval'] = 86_400

# Ensure the following group mappings in the group database
default['bcpc']['hadoop']['os']['group'].tap do |group|
  group['hadoop']['members'] = ['hdfs', 'yarn']
  group['hdfs']['members'] = ['hdfs']
  group['mapred']['members'] = ['yarn']
end

# Override defaults for the Java cookbook
default['java'].tap do |java|
  java['jdk_version'] = 7

  java['install_flavor'] = 'oracle'

  java['accept_license_agreement'] = true

  java['jdk']['7']['x86_64']['url'] =
    get_binary_server_url + 'jdk-7u51-linux-x64.tar.gz'

  java['jdk']['8']['x86_64']['url'] =
    get_binary_server_url + 'jdk-8u74-linux-x64.tar.gz'

  java['jdk']['8']['x86_64']['checksum'] =
    '0bfd5d79f776d448efc64cb47075a52618ef76aabb31fde21c5c1018683cdddd'

  java['oracle']['jce']['enabled'] = true

  java['oracle']['jce']['7']['url'] =
    get_binary_server_url + 'UnlimitedJCEPolicyJDK7.zip'

  java['oracle']['jce']['8']['url'] =
    get_binary_server_url + 'jce_policy-8.zip'
end

# Set the JAVA_HOME for Hadoop components
default['bcpc']['hadoop']['java'] = '/usr/lib/jvm/java-7-oracle-amd64'
default['bcpc']['cluster']['file_path'] = '/home/vagrant/chef-bcpc/cluster.txt'
