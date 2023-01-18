+++
title = "Init Script for Pyload on Gentoo"
date = "2012-06-30"
slug = "2012/06/30/init-script-for-pyload-on-gentoo"
description = "initscript to run pyload on gentoo as a service"
Categories = []
+++

Because I use a custom installation of [pyload](http://pyload.org/) I had to
write my own init script.

my setup:

- runs as a user with its home directory set to /home/pyload
- python files are located in /home/pyload/bin
- configuration files are located in /home/pyload/.pyload

Here is the init script I use:

```console /etc/init.d/pyload
#!/sbin/runscript

depend() {
    need net
}

PYLOAD_USER=${PYLOAD_USER:-root}
PYLOAD_GROUP=${PYLOAD_GROUP:-root}
PYLOAD_CONFDIR=${PYLOAD_CONFDIR:-/etc/pyload}
PYLOAD_PIDFILE=${PYLOAD_PIDFILE:-/var/run/${SVCNAME}.pid}
PYLOAD_EXEC=${PYLOAD_EXEC:-/usr/bin/pyload}

start() {
  ebegin "Starting pyload"
  start-stop-daemon --start --exec "${PYLOAD_EXEC}" \
      --pidfile $PYLOAD_PIDFILE \
      --user $PYLOAD_USER:$PYLOAD_GROUP \
      -- -p $PYLOAD_PIDFILE --daemon ${PYLOAD_OPTIONS}
  eend $? "Failed to start pyload"
}
stop() {
  ebegin "Stopping pyload"
  start-stop-daemon --stop \
    --pidfile $PYLOAD_PIDFILE \
    --exec "${PYLOAD_EXEC}"
  eend $? "Failed to stop pyload"
}
```

Here is the configuration:

```console /etc/conf.d/pyload
PYLOAD_USER=pyload
PYLOAD_GROUP=pyload
PYLOAD_EXEC=/home/pyload/bin/pyLoadCore.py
PYLOAD_CONFDIR=/home/pyload/.pyload
PYLOAD_PIDFILE=/home/pyload/${SVCNAME}.pid
PYLOAD_OPTIONS=
```
