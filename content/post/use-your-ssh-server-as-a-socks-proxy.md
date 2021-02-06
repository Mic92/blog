+++
title = "Use Your Ssh Server as a Socks Proxy"
date = "2012-06-09"
slug = "2012/06/09/use-your-ssh-server-as-a-socks-proxy"
Categories = ["ssh", "socks proxy", "browser"]
+++

Sometimes for whatever reason you want a secure internet connection. Maybe because you distrust your local network or your network filter some traffic. Openssh is able to speak the [SOCKS protocol](http://en.wikipedia.org/wiki/SOCKS), which does the trick.

Open you ~/.ssh/config on your local machine and add the following lines:
``` apache ~/.ssh/config
Host webtunnel
  HostName domain.tld # replace this with your ip or domain name of your server
  DynamicForward 1080
  User myuser # replace this with your ssh login name
```

next connect to your server like this
``` console
ssh webtunnel
```

This opens a socks connection on your local machine on port 1080.
Now you are able to set up every application to use this proxy.
These are the common required settings:
```
Server: localhost
Port: 1080
Proxy-Type: SOCKS5
```

Personally I use [FoxProxy Basic](http://getfoxyproxy.org/) extension for firefox to fast setup a connection, whenever needed.
