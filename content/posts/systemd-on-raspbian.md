+++
title = "Systemd on Raspbian"
date = "2012-09-19"
slug = "2012/09/19/systemd-on-raspbian"
Categories = ["systemd", "raspberry pie", "raspbian"]
+++

As I like the stability and raw speed of systemd, I wanted to leave debian's
init system behind and switch to systemd.

The basic installation is pretty easy:

    $ apt-get install systemd

Then you need to tell the kernel to use systemd as the init system:

To do so, append `init=/bin/systemd` to the end of `/boot/cmdline.txt` line

    $ cat /boot/cmdline.txt
    dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait init=/bin/systemd

If you reboot, systemd will be used instead of the default init script.

Currently debians version of systemd doesn't ship many service files by default.
Systemd will automatically fallback to the lsb script, if a service file for a
daemon is missing. So the speedup isn't as big as on other distributions such as
archlinux or fedora, which provide a deeper integration.

To get a quick overview, which services are started nativly, type the following
command:

    $ systemctl list-units

All descriptions containing `LSB: ` are launched through lsb scripts.

Writing your own service files, is straight forward. If you add custom service
files, put them in /etc/systemd/system, so they will not get overwritten by
updates.

To get further information about systemd, I recommend the
[great archlinux wiki article](https://wiki.archlinux.org/index.php/Systemd).

At the end of this article, I provide some basic one, I use. I port them over
mostly from archlinux. In the most cases, i just have adjusted the path of the
binary to get them working. (from /usr/bin to /usr/sbin for ex.) It is
important, that the service name match with the initscript, so it will be used
instead by systemd. This will not work in all cases like dhcpcd which contains
the specific network device (like dhcpcd@eth0). In this case, you have to remove
origin service with `update-rc.d` and enable the service file with
`systemctl enable`.

Also available as [gist](https://gist.github.com/ac8ab2e84125ededa5c5):

```plain /etc/systemd/system/dhcpcd@.service
# IMPORTANT: only works with dhcpcd5 not the old dhcpcd3!
[Unit]
Description=dhcpcd on %I
Wants=network.target
Before=network.target

[Service]
Type=forking
PIDFile=/run/dhcpcd-%I.pid
ExecStart=/sbin/dhcpcd -A -q -w %I
ExecStop=/sbin/dhcpcd -k %I

[Install]
Alias=multi-user.target.wants/dhcpcd@eth0.service
```

```plain /etc/systemd/system/monit.service
[Unit]
Description=Pro-active monitoring utility for unix systems
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/monit -I
ExecStop=/usr/bin/monit quit
ExecReload=/usr/bin/monit reload

[Install]
WantedBy=multi-user.target
```

```plain /etc/systemd/system/ntp.service
[Unit]
Description=Network Time Service
After=network.target nss-lookup.target

[Service]
Type=forking
PrivateTmp=true
ExecStart=/usr/sbin/ntpd -g -u ntp:ntp
ControlGroup=cpu:/

[Install]
WantedBy=multi-user.target
```

```plain /etc/systemd/system/sshdgenkeys.service
[Unit]
Description=SSH Key Generation
ConditionPathExists=|!/etc/ssh/ssh_host_key
ConditionPathExists=|!/etc/ssh/ssh_host_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_ecdsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_ecdsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_dsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_dsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_rsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_rsa_key.pub

[Service]
ExecStart=/usr/bin/ssh-keygen -A
Type=oneshot
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

```plain /etc/systemd/system/ssh.socket
[Unit]
Conflicts=ssh.service

[Socket]
ListenStream=22
Accept=yes

[Install]
WantedBy=sockets.target
```

```plain /etc/systemd/system/ssh@.service
[Unit]
Description=SSH Per-Connection Server
Requires=sshdgenkeys.service
After=syslog.target
After=sshdgenkeys.service

[Service]
ExecStartPre=/bin/mkdir -m700 -p /var/run/sshd
ExecStart=-/usr/sbin/sshd -i
ExecReload=/bin/kill -HUP $MAINPID
StandardInput=socket
```

```plain /etc/systemd/system/ifplugd@.service
[Unit]
Description=Daemon which acts upon network cable insertion/removal

[Service]
Type=forking
PIDFile=/run/ifplugd.%i.pid
ExecStart=/usr/sbin/ifplugd %i
SuccessExitStatus=0 1 2

[Install]
WantedBy=multi-user.target
```
