+++
title = "Solve Vivado Remote Connection Test Failed"
date = "2017-04-13"
slug = "2017/04/13/solve-vivado-remote-connection-test-failed"
Categories = []
+++

When you are trying to get Vivado Remote Connections working on Ubuntu, you might have an issue to establish the connection.
This can be easily solved by adding a symlink to your bash, called sh. You can do this for example using the following commands:

```console
$ mkdir -p ~/.local/bin
$ ln -s /bin/bash ~/.local/bin/sh
```

Thanks to ole2 for providing this solution in the xilinx forum, which you can find here:
[forum post](https://forums.xilinx.com/t5/Installation-and-Licensing/Vivado-2013-2-Launching-jobs-on-a-remote-host/td-p/396861)

As he points out, this seem to be a bug in Vivado. Vivado seems to call a script with #!/bin/sh and expects a bash to be executed. But for Ubuntu, /bin/sh points to /bin/dash per default. An alternative solution is to re-configure this link using:

```console
$ sudo dpkg-reconfigure dash 
```

I had this issue in Vivado 2016.4 and Ubuntu 16.04 LTS.
