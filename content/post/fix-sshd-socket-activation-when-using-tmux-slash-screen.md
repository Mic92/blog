+++
title = "Fix Sshd Socket Activation When Using Tmux Slash Screen"
date = "2015-04-13"
slug = "2015/04/13/fix-sshd-socket-activation-when-using-tmux-slash-screen"
Categories = []
+++

When using sshd.socket to start sshd on demand, detaching from a tmux/screen
session will not work. The reason is once the ssh session is closed, systemd
will terminate all remaining processes in the sshd cgroups, which affects also
the tmux/screen background process. However this behaviour can be changed using
the following drop-in file:

```plain /etc/systemd/system/sshd@.service.d/killmode.conf
[Service]
KillMode=process
```
