+++
title = "Use Systemd as a Cron Replacement"
date = "2013-06-09"
slug = "2013/06/09/use-systemd-as-a-cron-replacement"
Categories = ["systemd", "timer", "linux", "cron"]
+++

Since systemd 197 timer units support calendar time events, which makes systemd
a full cron replacement. Why one would replace the good old cron? Well, because
systemd is good at executing stuff and monitor its state!

- with the help of journalctl you get last status and logging output, which is a
  great thing to debug failing jobs:

```console
$ systemctl status reflector-update.service
reflector-update.service - "Update pacman's mirrorlist using reflector"
   Loaded: loaded
(/etc/systemd/system/timer-weekly.target.wants/reflector-update.service)
   Active: inactive (dead)

Jun 09 17:58:30 higgsboson reflector[30109]: rating http://www.gtlib.gatech.edu/pub/archlinux/
Jun 09 17:58:30 higgsboson reflector[30109]: rating rsync://rsync.gtlib.gatech.edu/archlinux/
Jun 09 17:58:30 higgsboson reflector[30109]: rating http://lug.mtu.edu/archlinux/
Jun 09 17:58:30 higgsboson reflector[30109]: Server Rate       Time
...
```

- there are a lot of useful
  [systemd unit options](http://www.freedesktop.org/software/systemd/man/systemd.exec.html)
  like `IOSchedulingPriority`, `Nice` or `JobTimeoutSec`
- it is possible to let depend units on other services, like mounting the nfs
  host before starting the mysql-backup.service or depending on the
  network.target.

So let's get it started. The first thing you might want to do, is to replace the
default scripts located in the
[runparts](http://superuser.com/questions/402781/what-is-run-parts-in-etc-crontab-and-how-do-i-use-it)
directories /etc/cron.{daily,hourly,monthly,weekly}.

On my distribution (archlinux) these are logrotate, man-db, shadow and updatedb:
For convenience I created a structure like /etc/cron.\*:

```console
$ mkdir /etc/systemd/system/timer-{hourly,daily,weekly}.target.wants
```

and added the following timer.

```console
$ cd /etc/systemd/system
$ wget https://blog.thalheim.io/downloads/timers.tar
$ tar -xvf timers.tar && rm timers.tar
```

```systemd
[Unit]
Description=Hourly Timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=1h
Unit=timer-hourly.target

[Install]
WantedBy=basic.target
```

```systemd
[Unit]
Description=Hourly Timer Target
StopWhenUnneeded=yes
```

```systemd
[Unit]
Description=Daily Timer

[Timer]
OnBootSec=10min
OnUnitActiveSec=1d
Unit=timer-daily.target

[Install]
WantedBy=basic.target
```

```systemd
[Unit]
Description=Daily Timer Target
StopWhenUnneeded=yes
```

```systemd
[Unit]
Description=Weekly Timer

[Timer]
OnBootSec=15min
OnUnitActiveSec=1w
Unit=timer-weekly.target

[Install]
WantedBy=basic.target
```

```systemd
[Unit]
Description=Weekly Timer Target
StopWhenUnneeded=yes
```

... and enable them:

```console
$ systemctl enable timer-hourly.timer
$ systemctl enable timer-daily.timer
$ systemctl enable timer-weekly.timer
```

These directories work like their cron equivalents, each service file located in
such a directory will be executed at the given time.

Now move on to the service files. If you're not running Arch, the paths might be
different on your system.

```console
$ cd /etc/systemd/system
$ wget https://blog.higgsboson.tk/downloads/services.tar
$ tar -xvf services.tar && rm services.tar
```

```systemd
[Unit]
Description=Update man-db

[Service]
Nice=19
IOSchedulingClass=2
IOSchedulingPriority=7
ExecStart=/usr/bin/logrotate /etc/logrotate.conf
```

```systemd
[Unit]
Description=Update man-db

[Service]
Nice=19
IOSchedulingClass=2
IOSchedulingPriority=7
ExecStart=/usr/bin/mandb --quiet
```

```systemd
[Unit]
Description=Update mlocate database

[Service]
Nice=19
IOSchedulingClass=2
IOSchedulingPriority=7
ExecStart=/usr/bin/updatedb
```

```systemd
[Unit]
Description=Verify integrity of password and group files

[Service]
Type=oneshot
ExecStart=/usr/sbin/pwck -r
ExecStart=/usr/sbin/grpck -r
```

At last but not least you can disable cron:

```console
$ systemctl stop cronie && systemctl disable cronie
```

If you want to execute at a special calendar events for example "every first day
in a month" use the
["OnCalendar=" option](http://www.freedesktop.org/software/systemd/man/systemd.time.html)
in the timer file. example:

```systemd send-bill.timer
[Unit]
Description=Daily Timer

[Timer]
OnCalendar=*-*-1 0:0:O
Unit=send-bill.target

[Install]
WantedBy=basic.target
```

That's all for the moment. Have a good time using the power of systemd!

Below some service files, I use:

```systemd
[Unit]
Description="Update pacman's mirrorlist using reflector"

[Service]
Nice=19
IOSchedulingClass=2
IOSchedulingPriority=7
Type=oneshot
ExecStart=/usr/bin/reflector --verbose -l 5 --sort rate --save /etc/pacman.d/mirrorlist
```

```systemd
[Unit]
Description=Run pkgstats

[Service]
User=nobody
ExecStart=/usr/bin/pkgstats
```

[See this link](https://bbs.archlinux.org/viewtopic.php?id=162989) for details
about my shell-based pacman notifier

```systemd
[Unit]
Description=Update pacman's package cache

[Service]
Nice=19
Type=oneshot
IOSchedulingClass=2
IOSchedulingPriority=7
Environment=CHECKUPDATE_DB=/var/lib/pacman/checkupdate
ExecStartPre=/bin/sh -c "/usr/bin/checkupdates &gt; /var/log/pacman-updates.log"
ExecStart=/usr/bin/pacman --sync --upgrades --downloadonly --noconfirm --dbpath=/var/lib/pacman/checkupdate
```
