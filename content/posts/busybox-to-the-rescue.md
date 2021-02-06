+++
title = "Busybox to the Rescue"
date = "2014-01-30"
slug = "2014/01/30/busybox-to-the-rescue"
Categories = []
+++

Some days before I broke my raspberry pie, after pacman running out of memory, while
updating my glibc. To solve such problems on any of my machines, I decided to
setup rescue systems with busybox. Therefor just install the package *busybox*
on archlinux or *busybox-static* if you are on debian.
Busybox is a so called multi-call binary.
This means, it exposes different behaviour depending on the program name, which
is used to execute it. As a basic environment for the rescue system, I created a
symlinks for every command which busybox is capable of:

    $ sudo mkdir /opt/busybox/bin

    $ busybox --list | xargs -n 1 -d "\n" -I "cmd" sudo ln -s $(which busybox) /opt/busybox/bin/cmd

In order to be able to login in a system, where the usual shell is broken, I
added a new user called *rescue*.

    $ useradd -m -s /opt/busybox/bin/ash rescue

Because origin passwd uses sha256 for password hashes, which busybox is not
capable of by default you have to recreate every password, you plan to login, to
make things like su work:

    $ sudo busybox passwd -a 2 rescue # use sha1 instead of sha256
    $ sudo busybox passwd -a 2 root

The login shell is set in this case to the one busybox provides.
In order to be able to login via ssh this shell has to be added
*/etc/shells*:

    $ echo /opt/busybox/bin/ash | sudo tee -a /etc/shells

The last thing left, is to prepend the path with busybox symlinks, to the PATH
variable of the rescue user, to use them instead of their coreutils equivalents.

    $ echo 'export PATH=/opt/busybox/bin:$PATH' | sudo tee -a /home/rescue/.profile
