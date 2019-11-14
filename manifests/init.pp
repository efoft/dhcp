# @summary   Installs and configures isc-dhcpd.
#
# @param ddns_key_name #   Name of the DDNS update key as it specified in *ddns_key_path* file.
#
# @param ddns_key_path
#   Absolute path to the file where DDNS update key is stored. This file must
#   be generated with BIND tools and must exists prior DHCP daemon startup.
#
# @param failover       Activates failover mechanism between 2 DHCP servers to support the same network.
# @param failover_role  Can be: primary, secondary.
# @param failover_myip  Local IP address that is used in the cluster heartbeat.
# @param failover_peer  Failover cluster peer IP address to communicate with.
# @param failover_port  TCP-port of primary and secondary nodes in failover cluster, used in heartbeat.
# @param subnets        Data to configure subnets, pools and ranges. See details in dhcp::subnet.
# @param omapi_enable   If to include omapi configuration into dhcpd.conf
# @param omapi_port     Default is 7911
# @param omapi_key_name Name of the omapi key
# @param omapi_key      Value for omapi key, how to generate https://projects.theforeman.org/projects/smart-proxy/wiki/ISC_DHCP
#
# @param static_hosts
#   Static hosts declaration. Example of hash (hiera format):
#   ---
#   testhost1:
#      ip: 10.1.1.22
#      mac: '00:00:00:0c:be:12'
#      comment: 'John laptop'
#   testhost2:
#      ip: 10.1.1.23
#      mac: '00:00:00:0c:be:13'
#      comment: 'Sarah laptop'
#
class dhcp (
  Enum['present','absent']      $ensure           = 'present',
  Optional[String]              $listen_if        = undef,
  # DDNS
  String                        $ddns_key_name    = $dhcp::params::ddns_key_name,
  Stdlib::Unixpath              $ddns_key_path    = $dhcp::params::ddns_key_path,
  # Failover cluster
  Boolean                       $failover         = false,
  Enum['primary','secondary']   $failover_role    = 'primary',
  Stdlib::Ip::Address           $failover_myip    = $facts['networking']['ip'],
  Optional[Stdlib::Ip::Address] $failover_peer    = undef,
  String                        $failover_cluster = $dhcp::params::failover_cluster,
  Numeric                       $failover_port    = $dhcp::params::failover_port,
  # OMAPI
  Boolean                       $omapi_enable     = false,
  Numeric                       $omapi_port       = 7911,
  String                        $omapi_key_name   = 'omapi_key',
  Optional[String]              $omapi_key        = undef,
  # Networks & hosts
  Hash                          $subnets          = {},
  Hash                          $static_hosts     = {},
) inherits dhcp::params {

  if $failover and ! $failover_peer {
    fail('For failover cluster failover peer IP must be set')
  }

  if $omapi_enable and ! $omapi_key {
    fail('omapi_key is required if omapi_enable is true')
  }

  package { $package_name:
    ensure => $ensure ? { 'present' => 'installed', 'absent' => 'purged' },
  }

  Concat {
    ensure  => $ensure,
    require => Package[$package_name],
    notify  => Service[$service_name],
  }

  File {
    ensure  => $ensure,
    require => Package[$package_name],
    notify  => Service[$service_name],
  }

  concat { $maincfg: }
  concat::fragment { "global-settings-in-${maincfg}":
    target  => $maincfg,
    content => template('dhcp/dhcpd.conf_global.erb'),
    order   => '01',
  }
  @concat::fragment { "enable-pxe-in-${maincfg}":
    target  => $maincfg,
    content => template('dhcp/dhcpd.conf_pxe.erb'),
    order   => '02',
  }
  @concat::fragment { "enable-ddns-in-${maincfg}":
    target  => $maincfg,
    content => template('dhcp/dhcpd.conf_ddns.erb'),
    order   => '03',
  }
  concat::fragment { "static-hosts-in-${maincfg}":
    target  => $maincfg,
    content => template('dhcp/dhcpd.conf_static.erb'),
    order   => '06',
  }

  file {
    $daemoncfg:
      content => template("dhcp/${daemontmpl}");
    $hostscfg:
      content => template('dhcp/dhcphosts.cf.erb');
  }

  create_resources('dhcp::subnet', $subnets)

  service { $service_name:
    ensure    => $ensure ? { 'present' => 'running', 'absent' => undef },
    enable    => $ensure ? { 'present' => true, 'absent' => false },
    hasstatus => true,
  }
}
