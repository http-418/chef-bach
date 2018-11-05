name             'bcpc'
maintainer       'Bloomberg Finance L.P.'
maintainer_email 'hadoop@bloomberg.net'
license          'Apache License 2.0'
description      'Installs/Configures Bloomberg Clustered Private Cloud (BCPC)'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

depends 'apt'
depends 'bfd'
depends 'bach_repository'
depends 'build-essential'
depends 'chef-client'
depends 'chef-vault', '~>2.0'
depends 'cobblerd'
depends 'cron'
depends 'database'
depends 'graphite_handler'
depends 'line', '< 2.0.0' # 2.0.0 drops Chef 12.0 support
depends 'maven', '~> 5.0.1'
depends 'nscd'
depends 'ntp'
depends 'python'
depends 'ubuntu'
depends 'sudo'
depends 'pdns'
