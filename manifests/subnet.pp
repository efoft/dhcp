# === Define dhcp::subnet ===
#
# This module only supports subnet declaraion with pools. Pools allow to split network
# into several ranges with different settings.
#
# === Parameters ===
# [*network*]
#   Subnetwork address.
#
# [*netmask*]
#   Subnetwork mask.
#
# [*router*]
#   IP address of the network router.
#
# [*domain*]
#   Domain name to assign to clients.
#
# [*dns_servers*]
#   Array of IP addresses of DNS servers. If ddns is used then first element is array must be primary DNS server.
#
# [*netbios_servers*]
#   Optional. Array of addresses of WINS-servers (if used).
#
# [*failover*]
#   If this subnet must be included into cluster configuration.
#
# [*failover_cluster*]
#   The name of cluster, fetched from main class.
#
# [*ddns*]
#   Boolean to say if DDNS updates are used for this subnet.
#
# [*ddns_zones*]
#   Array of zones that are served by the BIND server which are to be updated.
#   Default: zone with the same name as *domain*
#
# [*ddns_primary*]
#   Reassign used by default first item of *dns_servers* array.
#
# [*ddns_key_name*]
#   Name of the rndc key, fetched from main class.
#   Default: rndc-key
#
# [*next_server*]
#   IP address of pxe boot server where boot image resides. Can be defined on the subnet level (here)
#   or otherwise be specific for each pool and defined in a pool.
#
# [*filename*]
#   The name of boot image for pxe. Can be defined on the subnet level (here)
#   or otherwise be specific for each pool and defined in a pool.
#   Default: pxelinux.0
#
# [*ttl*]
#   Default lease time and max lease time are set to this value.
#   Default: 43200 sec
#
# [*pools*]
#   Hash must contain the following keys:
#   - start: first IP of the range
#   - end:   last IP of the range
#   Can also contain keys:
#   - static_only: means that pool only serves the clients that are staticly declared
#   - pxe
#   - next_server
#   - filename
#   - ttl
#
define dhcp::subnet (
  Stdlib::Ip::Address $network,
  Stdlib::Ip::Address $netmask,
  Stdlib::Ip::Address $router,
  String $domain,
  Array[Stdlib::Ip::Address] $dns_servers,
  Array[Stdlib::Ip::Address] $netbios_servers  = [],
  Boolean $failover                            = $dhcp::failover,
  String $failover_cluster                     = $dhcp::failover_cluster,
  Boolean $ddns                                = false,
  Optional[Array[String]] $ddns_zones          = undef,
  Optional[Stdlib::Ip::Address] $ddns_primary  = undef,
  String $ddns_key_name                        = $dhcp::ddns_key_name,
  Optional[Stdlib::Ip::Address] $next_server   = undef,
  String $filename                             = $dhcp::params::filename,
  Numeric $ttl                                 = 43200,
  Hash $pools,
) {

  $_ddns_zones = $ddns_zones ?
  {
    undef   => [$domain],
    default => $ddns_zones
  }

  $_ddns_primary = $ddns_primary ?
  {
    undef   => $dns_servers[0],
    default => $ddns_primary
  }

  $pxe_pools = inline_template("<%= @pools.select{|k,v| v['pxe'] == true}.map{|k,| k}.join(',') %>").split(',')

  if ! empty($pxe_pools) {
    realize(Concat::Fragment["enable-pxe-in-${dhcp::params::maincfg}"])
  }

  if $ddns {
    realize(Concat::Fragment["enable-ddns-in-${dhcp::params::maincfg}"])

    concat::fragment { "ddns-zones-in-${network}-${netmask}":
      target  => $dhcp::params::maincfg,
      content => template('dhcp/dhcpd.conf_zones.erb'),
      order   => '04',
    }
  }

  concat::fragment { "subnet-${network}-${netmask}":
    target  => $dhcp::params::maincfg,
    content => template('dhcp/dhcpd.conf_subnet.erb'),
    order   => '05',
  }
}
