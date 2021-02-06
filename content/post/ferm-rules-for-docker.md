+++
title = "Ferm Rules for Docker"
date = "2014-11-01"
slug = "2014/11/01/ferm-rules-for-docker"
Categories = []
+++

The Docker daemon add his own custom rules by default to iptables.  If you use
[ferm](http://ferm.foo-projects.org/) to manage your iptables rules, it is a
good idea to prepopulate rules for docker. Otherwise they will be overwritten by
ferm as it restarts.

To do so add the following lines at the top of your ferm.conf:

```
domain ip {
    table filter chain FORWARD {
        outerface docker0 mod conntrack ctstate (RELATED ESTABLISHED) ACCEPT;
        interface docker0 outerface !docker0 ACCEPT;
        interface docker0 outerface docker0 ACCEPT;
    }
    table nat {
        chain DOCKER;
        chain PREROUTING {
           mod addrtype dst-type LOCAL jump DOCKER;
        }
        chain OUTPUT {
           daddr !127.0.0.0/8 mod addrtype dst-type LOCAL jump DOCKER;
        }

        chain POSTROUTING {
           saddr 172.17.0.0/16 outerface !docker0 MASQUERADE;
        }
    }
}
```

In my case docker's subnet is `172.17.0.0/16` and uses `docker0` as bridge
device.
