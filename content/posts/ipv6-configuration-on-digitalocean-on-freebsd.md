+++
title = "Ipv6 Configuration on Digitalocean on Freebsd"
date = "2015-01-19"
slug = "2015/01/19/ipv6-configuration-on-digitalocean-on-freebsd"
Categories = ["freebsd", "digitalocean", "network"]
+++

By default Digitalocean add some custom rc.d scripts for network configuration
to your droplet.

You can just append the content of `/etc/rc.digitalocean.d/droplet.conf` to your
`/etc/rc.conf` In my case the public ipv4 address is `188.166.0.1` and my first
ipv6 address is `2a03:b0c0:2:d0::2a5:f001`.

```bash /etc/rc.conf
defaultrouter="188.166.0.1"
# ipv6 address are shortend for readability
ipv6_defaultrouter="2a03:b0c0:2:d0::1"
ifconfig_vtnet0="inet 188.166.16.37 netmask 255.255.192.0"
ifconfig_vtnet0_ipv6="inet6 2a03:b0c0:2:d0::2a5:f001 prefixlen 64"
```

Digitalocean provides these days for native Ipv6 for the most of its
datacenters. Unlike other hoster they are very spare, when distributing Ipv6
Addresses and only route 16 addresses per droplet
(xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxx1 until xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxf).
To make use of these additional ip addresses they have to be assigned to your
network interface `vtnet0`:

```bash /etc/rc.conf
ifconfig_vtnet0_aliases="\
                      inet6 2a03:b0c0:2:d0::2a5:f002 prefixlen 64 \
                      inet6 2a03:b0c0:2:d0::2a5:f003 prefixlen 64 \
                      inet6 2a03:b0c0:2:d0::2a5:f004 prefixlen 64 \
                      inet6 2a03:b0c0:2:d0::2a5:f005 prefixlen 64 \
                      inet6 2a03:b0c0:2:d0::2a5:f006 prefixlen 64 \
                      inet6 2a03:b0c0:2:d0::2a5:f007 prefixlen 64 \
                      inet6 2a03:b0c0:2:d0::2a5:f008 prefixlen 64 \
                      inet6 2a03:b0c0:2:d0::2a5:f009 prefixlen 64 \
                      inet6 2a03:b0c0:2:d0::2a5:f00a prefixlen 64 \
                      inet6 2a03:b0c0:2:d0::2a5:f00b prefixlen 64 \
                      inet6 2a03:b0c0:2:d0::2a5:f00c prefixlen 64 \
                      inet6 2a03:b0c0:2:d0::2a5:f00d prefixlen 64 \
                      inet6 2a03:b0c0:2:d0::2a5:f00e prefixlen 64 \
                      inet6 2a03:b0c0:2:d0::2a5:f00f prefixlen 64"
```

In case you want to add freebsd jails later on, it is a good idea to allocate
private ipv4 addresses for these too. In my case I generated as many ipv4
address as ipv6 addresses I got:

```bash
cloned_interfaces="${cloned_interfaces} lo1"
ifconfig_lo1_aliases="\
                      inet 192.168.67.1/24 \
                      inet 192.168.67.2/24 \
                      inet 192.168.67.3/24 \
                      inet 192.168.67.4/24 \
                      inet 192.168.67.5/24 \
                      inet 192.168.67.6/24 \
                      inet 192.168.67.7/24 \
                      inet 192.168.67.8/24 \
                      inet 192.168.67.9/24 \
                      inet 192.168.67.10/24 \
                      inet 192.168.67.11/24 \
                      inet 192.168.67.12/24 \
                      inet 192.168.67.13/24 \
                      inet 192.168.67.14/24 \
                      inet 192.168.67.15/24"
```

To apply these network settings immediately issue the following commands in
series:

```console
$ sudo service netif restart; sudo /etc/rc.d/routing restart
```

The second command is important because it adds the ipv4 gateway back. Otherwise
you will not reach your droplet via ipv4 without rebooting.

If everything still works, you can remove, the following files leftover from
cloudflare's provisioning:

```console
$ rm /etc/rc.d/digitalocean
$ rm -r /etc/rc.digitalocean.d
$ rm -r /usr/local/bsd-cloudinit/
$ pkg remove avahi-autoipd
```
