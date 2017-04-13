default['bach']['repository'].tap do |repo|
  repo['chefdk'] =
    {
     url: 'https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/' \
       '14.04/x86_64/chefdk_0.12.0-1_amd64.deb',
     sha256: '6fcb4529f99c212241c45a3e1d024cc1519f5b63e53fc1194b5276f1d8695aaa'
    }

  repo['chef'] =
    {
     url: 'https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/' \
       '14.04/x86_64/chef_12.8.1-1_amd64.deb',
     sha256: '92b7f3eba0a62b20eced2eae03ec2a5e382da4b044c38c20d2902393683c77f7'
    }

  repo['chef_server'] =
    {
     url: 'https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/' \
       '12.04/x86_64/chef-server_11.1.1-1_amd64.deb',
     sha256: 'b6c354178cc83ec94bea40a018cef697704415575c7797c4abdf47ab996eb258'
    }
end
