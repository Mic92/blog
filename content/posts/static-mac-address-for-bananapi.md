+++
title = "Static Mac Address for Bananapi"
date = "2015-01-06"
slug = "2015/01/06/static-mac-address-for-bananapi"
Categories = ["linux", "bananapi", "network"]
+++

The bananapi does currently assign random mac addresses to its ethnernet nic,
which is bad if you want to assign static dhcp leases. To solve this issue just
create the following udev rule:

```plain /etc/udev/rules.d/75-static-mac
ACTION=="add", SUBSYSTEM=="net", ATTR{dev_id}=="0x0", RUN+="/usr/bin/ip link set dev %k address XX:XX:XX:XX:XX:XX"
```

Replace XX:XX:XX:XX:XX:XX with your current mac address:

```console
$ ip address
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 16436 qdisc noqueue state UNKNOWN group
default
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP
group default qlen 1000
    link/ether 02:8a:03:43:02:2a brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.56/24 brd 192.168.1.255 scope global eth0
    inet6 fe80::8a:3ff:fe43:22a/64 scope link
       valid_lft forever preferred_lft forever
    inet6 fe80::9985:bd71:3b59:4875/64 scope link
       valid_lft forever preferred_lft forever

```

which is `02:8a:03:43:02:2a` in my case.
