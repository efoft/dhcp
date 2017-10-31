# puppet-dnsmasq module
Puppet 4 module to install and configure isc-dhcp.

## Installation
Clone into puppet's modules directory.
```
git clone https://github.com/efoft/puppet-dhcp.git dhcp
```

## Examples of usage
```
class { '::dhcp':
  subnets      => $subnets,
  static_hosts => $static_hosts,
}
```
Parameter $subnets describe subnet declaraion. This module use pools within subnet. Pools allow to split single network into ranges with different settings.

Subnet mast have parameters:
* network
* netmask
* router
* domain
* dns_servers
* pools

It can also contain optional parameters:
* failover - if to include this instance of dhcp into failover cluster. See failover_* params in the module doc.
* ddns - if to update BIND DNS server dynamicly with records for assigned addresses. For this case BIND must be installed and set up to use DDN, key file is required.
* ddns_zones - array of BIND zone names to be dynamicly updated
* next_server and filename are subnet level defined options to set up pxe boot. They can also be defined or overriden at pool level.

Pools are dhcp IP ranges that must have parameters:
* start - first IP address in a range
* end   - last IP address in a range
Pools can contain some optional parameters:
* static_only - means that this range is used to serve only staticly declared hosts
* pxe - if to enable booting clients via network using this range.
* next_server and filename - can be defined here as well as at subnet level
* ttl - default and max lease time in seconds.

Keys in subnets and pools hashes are treated as their names and can be any arbitary word.

Below are sample configuration stored in hiera:
```
subnets:
  lan:
    network: 192.168.1.0
    netmask: 255.255.255.0
    router:  192.168.1.1
    domain:  'local'
    dns_servers: [192.168.1.1]
    ddns:    true
    ddns_zones: [ 'local', '1.168.192.in-addr.arpa'],
    pools:
      registered:
        start: 192.168.1.2
        end:   192.168.1.99
        static_only: true
      public:
        start: 192.168.1.100
        end:   192.168.1.199
        ttl:   21600
      pxe:
        start: 192.168.1.200
        end:   192.168.1.209
        pxe:   true
        next_server: 192.168.1.20
static_hosts:
  testhost1: 
    ip: 192.168.1.10
    mac: '00:00:00:0c:be:12'
    comment: 'My laptop'
```
