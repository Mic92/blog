+++
title = "Deploykit 1.0: A Python library for parallel deployment and maintaince task over ssh and locally"
date = "2022-01-30"
slug = "2022/01/30/deploykit"
Categories = [ "python", "devops", "ssh" ]
+++

When I started working on a growing fleet of NixOS machines, I eventually gained
the need for running automating smaller maintenance tasks in parallel on a
number of machines. I found a bunch of tools that seemed to fit the bill:
ansible, fabric, <TODO>.

While ansible seemed like the closest to my feature set it had a slow startup
and a lot of unneccessary features, since NixOS already covers most of the
configuration management part. Also it would captures the output of my remote
processes until they finish, while quite often when deploying NixOS machines I
rather prefer to get output as quickly as possible to see if something goes
wrong during system activation. Another limitation in most of these tools I
found, that they do not allow to run local commands in parallel. I.e. for my
nixos machines, I often upload the nixos configuration with rsync in order to
activate it on the remote machine.

After fighting against limitations of the existing tools for a while, I decided
to just write a simple python wrapper around ssh that spawns a number of thread.
For a long time this simple wrapper was just copied into every project where I
needed to deploy nixos machines.

With each new project the code also matured to the point where I had give it its
own repository, so that I can manage these modifications in central place.
[Deploykit](https://github.com/numtide/deploykit) was born.

Here is a simple example on what its API, looks like

```python
from deploykit import parse_hosts
import subprocess

hosts = parse_hosts("server1,server2,server3")
runs = hosts.run("uptime", stdout=subprocess.PIPE)
for r in runs:
    print(f"The uptime of {r.host.hostname} is {r.result.stdout}")
```

I often use `deploykit` in combination with [pyinvoke](). Which gives me a
simple commandline to run these tasks:

```
inv reboot --hosts somehost
```

```python
from invoke import task
from deploykit import DeployHost, DeployGroup
import subprocess

def wait_for_host(host: str, shutdown: bool = False) -> None:
    import socket, time

    # Ping until the host is no longer reachable on shutdown and up when booting.
    while True:
        res = subprocess.run(
            ["ping", "-q", "-c", "1", "-w", "2", host], stdout=subprocess.DEVNULL
        )
        if shutdown:
            if res.returncode == 1:
                break
        else:
            if res.returncode == 0:
                break
        time.sleep(1)
        sys.stdout.write(".")
        sys.stdout.flush()


@task
def reboot(c, hosts=""):
    """
    Reboot hosts. example usage: inv reboot --hosts somehost
    """
    deploy_hosts = [DeployHost(h, user="root") for h in hosts.split(",")]
    for h in deploy_hosts:
        h.run("reboot &")

        print(f"Wait for {h.host} to shutdown", end="")
        sys.stdout.flush()
        wait_for_host(h.host, shutdown=True)
        print("")

        print(f"Wait for {h.host} to start", end="")
        sys.stdout.flush()
        wait_for_host(h.host)
        print("")
```

Lastly my own personal use case is evolves mostly around deploying new
configuration to nixos machines. As you can see in this example, deploykit not
only allows to run a simple command in parallel on multiple hosts, but also
python functions, which allows for more flexibility i.e. by incorperating host
specific parameters into remote commands.

```
def deploy_nixos(hosts: List[DeployHost]) -> None:
    """
    Deploy to all hosts in parallel
    """
    g = DeployGroup(hosts)

    def deploy(h: DeployHost) -> None:
        h.run_local(
            f"rsync -vaF --delete -e ssh . {h.user}@{h.host}:/etc/nixos"
        )

        flake_path = "/etc/nixos"
        flake_attr = h.meta.get("flake_attr")
        if flake_attr:
            flake_path += "#" + flake_attr
        target_host = h.meta.get("target_host", "localhost")
        h.run(
            f"nixos-rebuild switch --option accept-flake-config true --build-host localhost --target-host {target_host} --flake {flake_path}"
        )

    g.run_function(deploy)

HOSTS = [
    "host1",
    "host2",
    # ....
]

@task
def deploy(c):
    """
    Deploy to servers
    """
    deploy_nixos([DeployHost(h, user="root") for h in HOSTS])
```

That's all for today. I consider my work deploykit finished. I consider its API
stable and only plan to add smaller bugfixes and features to it.

If you like to use `deploykit` in your project, either consider downloading the
library from pypi, or use the nix flakes if case you are using the nix package
manager.
