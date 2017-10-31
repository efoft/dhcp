# === Class dhcp ===
#
# Installs and configures ics-dhcpd.
#
# === Parameters
# [*ddns_key_name*]
#   Name of the DDNS update key as it specified in *ddns_key_path* file.
#   Default: rndc-key
#
# [*ddns_key_path*]
#   Absolute path to the file where DDNS update key is stored. This file must
#   be generated with BIND tools and must exists prior DHCP daemon startup.
#
# [*failover*]
#   Activates failover mechanism between 2 DHCP servers to support the same network.
#
# [*failover_role*]
#   Can be: primary, secondary.
#   Default: primary
#
# [*failover_myip*]
#   Local IP address that is used in the cluster heartbeat.
#   Default: primary IP from facter
#
# [*failover_peer*]
#   Failover cluster peer IP address to communicate with.
#
# [*failover_port*]
#   TCP-port of primary and secondary nodes in failover cluster, used in heartbeat.
#   Default: 647
#
# [*subnets*]
#   Data to configure subnets, pools and ranges. See details in dhcp::subnet.
#
# [*static_hosts*]
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
  Enum['present','absent'] $ensure                = 'present',
  Optional[String] $listen_if                     = undef,
  # DDNS
  String $ddns_key_name                           = $dhcp::params::ddns_key_name,
  Stdlib::Unixpath $ddns_key_path                 = $dhcp::params::ddns_key_path,
  # Failover cluster
  Boolean $failover                               = false,
  Enum['primary','secondary'] $failover_role      = 'primary',
  Stdlib::Compat::Ipv4 $failover_myip             = $facts['networking']['ip'],
  Optional[Stdlib::Compat::Ipv4] $failover_peer   = undef,
  String $failover_cluster                        = $dhcp::params::failover_cluster,
  Numeric $failover_port                          = $dhcp::params::failover_port,
  # Networks & hosts
  Hash $subnets                                   = {},
  Hash $static_hosts                              = {},
) inherits dhcp::params {

  if $failover and ! $failover_peer {
    fail('For failover cluster failover peer IP must be set')
  }

  package { $dhcp::params::package_name:
    ensure => $ensure ? { 'present' => 'installed', 'absent' => 'purged' },
  }

  Concat {
    ensure  => $ensure,
    require => Package[$dhcp::params::package_name],
    notify  => Service[$dhcp::params::service_name],
  }

  File {
    ensure  => $ensure,
    require => Package[$dhcp::params::package_name],
    notify  => Service[$dhcp::params::service_name],
  }

  concat { $dhcp::params::maincfg: }
  concat::fragment { "global-settings-in-${dhcp::params::maincfg}":
    target  => $dhcp::params::maincfg,
    content => template('dhcp/dhcpd.conf_global.erb'),
    order   => '01',
  }
  @concat::fragment { "enable-pxe-in-${dhcp::params::maincfg}":
    target  => $dhcp::params::maincfg,
    content => template('dhcp/dhcpd.conf_pxe.erb'),
    order   => '02',
  }
  @concat::fragment { "enable-ddns-in-${dhcp::params::maincfg}":
    target  => $dhcp::params::maincfg,
    content => template('dhcp/dhcpd.conf_ddns.erb'),
    order   => '03',
  }
  concat::fragment { "static-hosts-in-${dhcp::params::maincfg}":
    target  => $dhcp::params::maincfg,
    content => template('dhcp/dhcpd.conf_static.erb'),
    order   => '06',
  }

  file {
    $dhcp::params::daemoncfg:
      content => template("dhcp/${dhcp::params::daemontmpl}");
    $dhcp::params::hostscfg:
      content => template('dhcp/dhcphosts.cf.erb');
  }

  create_resources('dhcp::subnet', $subnets)

  service { $dhcp::params::service_name:
    ensure    => $ensure ? { 'present' => 'running', 'absent' => undef },
    enable    => $ensure ? { 'present' => true, 'absent' => false },
    hasstatus => true,
  }
}
