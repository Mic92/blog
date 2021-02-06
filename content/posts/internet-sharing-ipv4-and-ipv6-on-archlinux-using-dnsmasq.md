+++
title = "Internet Sharing Ipv4 and Ipv6 on Archlinux Using Dnsmasq"
date = "2014-02-08"
slug = "2014/02/08/internet-sharing-ipv4-and-ipv6-on-archlinux-using-dnsmasq"
Categories = ["arch", "dhcp", "ipv6 router advertisement", "network"]
+++

**Update:** Added adhoc wlan network

A guide to connect with a different machine using a ethernet cable for
internet sharing or just transferring files:

1. Install dnsmasq and iproute2

    $ pacman -S dnsmasq iproute2

2. Copy over the configuration files at the end of the article and edit the
   */etc/conf.d/share-internet@\<device\>* to match your network setup. (where
   \<device\> is your network device)

3. Start the sharing service with systemd

   $ sudo systemctl start internet-sharing@<device>.service

After that the other machine can connect via dhcp. It will get an ipv4
address from the **10.20.0.0/24** subnet and a ipv6 address from the **fd21:30c2:dd2f::**
subnet. Your host will be reachable via **10.20.0.1** or **fd21:30c2:dd2f::1**.
Thanks to ipv6 router advertising, an AAAA record for each host is automatically set based on the hostname.
This means if your hostname is *foo*, all members of the network can just connect
to it using the address *foo*. You should disable the share-internet.service, if
you don't need it. Otherwise you might mess up network setups, if you connect to a
network with the device on which the dhcp service is running.

Happy networking!

```
# google as an upstream dns server
server=8.8.8.8
server=8.8.4.4
no-resolv
cache-size=2000
```

Ethernet to Wlan:

```
# Device which has internet access, ex: wlan0 or usb0
EXTERNAL_DEVICE="wlp3s0"

IP4_ADDRESS="10.20.0.1"
IP4_NETMASK="24"
IP4_SUBNET="10.20.0.2,10.20.0.255"

IP6_ADDRESS="fd21:30c2:dd2f::1"
IP6_NETMASK="64"
IP6_SUBNET="fd21:30c2:dd2f::"
```

Wlan to Ethernet:

If you have luck and your wifi driver is capable of the infrastructure mode,
you should take a look at hostadp, in my case I have to create an adhoc network.
To enable the adhoc network:

   $ sudo systemctl enable wireless-adhoc@\<device\>.service

```
# Device which has internet access, ex: wlan0 or usb0
EXTERNAL_DEVICE="enp0s20u2"

IP4_ADDRESS="10.20.0.1"
IP4_NETMASK="24"
IP4_SUBNET="10.20.0.100,10.20.0.199"

IP6_ADDRESS="fd21:30c2:dd2f::1"
IP6_NETMASK="64"
IP6_SUBNET="fd21:30c2:dd2f::"
```

```systemd
[Unit]
Description=Ad-hoc wireless network connectivity (%i)
Wants=network.target
Before=network.target
Conflicts=netctl-auto@.service
BindsTo=sys-subsystem-net-devices-%i.device
After=sys-subsystem-net-devices-%i.device

[Service]
Type=simple
ExecStartPre=/usr/bin/rfkill unblock wifi
ExecStart=/usr/sbin//wpa_supplicant -D nl80211,wext -c/etc/wpa_supplicant/wpa_supplicant-adhoc-%I.conf -i%I

[Install]
RequiredBy=share-internet@%i.service
```

```
ctrl_interface=DIR=/run/wpa_supplicant GROUP=wheel

# use 'ap_scan=2' on all devices connected to the network
ap_scan=2

network={
    ssid="The.Secure.Network"
    mode=1
    frequency=2432
    proto=WPA
    key_mgmt=WPA-NONE
    pairwise=NONE
    group=TKIP
    psk="fnord"
}

# MacOS X and Networmanager aren't capable of using WPA/WPA2 for Adhoc Networks
#network={
#    ssid="The.Insecure.Network"
#    mode=1
#    frequency=2432
#    proto=WPA
#    key_mgmt=NONE
#    pairwise=NONE
#    group=TKIP
#
#    wep_key0="fnord"
#    wep_tx_keyidx=0
#}
```
