# === Class dhcp::params ===
#
class dhcp::params {

  case $facts['os']['family'] {
    'RedHat': {
      $package_name = 'dhcp'
      $service_name = 'dhcpd'
      $maincfg      = '/etc/dhcp/dhcpd.conf'
      $hostscfg     = '/etc/dhcp/dhcphosts.conf'

      if $facts['os']['release']['major'] == '6' {
        $daemoncfg = '/etc/sysconfig/dhcpd'
        $daemontmpl = 'dhcpd.sysconfig.erb'
      }
      elsif $facts['os']['release']['major'] == '7' {
        $daemoncfg = '/etc/systemd/system/dhcpd.service'
        $daemontmpl = 'dhcpd.service.erb'
      }
      else {
        fail('Sorry! Your OS version is not supported.')
      }

      $ddns_key_name = 'rndc-key'
      $ddns_key_path = '/etc/rndc.key'
    }
    default: {
      fail('Sorry! Your OS is not supported.')
    }
  }

  $failover_cluster = 'dhcp_cluster'
  $failover_port    = 647
  $filename         = 'pxelinux.0'
}
