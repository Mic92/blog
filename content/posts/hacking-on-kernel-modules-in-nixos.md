---
title: "Hacking on Kernel Modules in NixOS"
date: 2022-12-17T20:50:21+01:00
categories: ["nixos", "kernel"]
author: ["Jörg Thalheim and Alex A. Renoire"]
---

Lately, I hacked on some kernel modules to get more debug logs out of a kernel
module on my NixOS machine. Because NixOS does not follow the Filesystem
Hierarchy Standard (FHS) for filesystem layouts, the standard kernel hacker
tutorials won't fully apply to NixOS. However, by leveraging the NixOS
configuration, we can quickly set up an environment that allows us to compile
the Linux kernel and its modules.

# Where can you define the kernel?

Commonly, Linux distributions put their kernel sources in `/usr/src` and their
kernel modules in `/lib/modules/$(uname -r)`. Like always, NixOS is a special
snowflake, but once you get to learn the mechanics, it is actually quite
pleasant to use.

In the NixOS configuration, the kernel is defined via the `boot.kernelPackages`
option. The former also defines all out-of-tree kernel modules and other
packages that have the kernel as a build dependency. So, to access the kernel
only, you should look into `boot.kernelPackages.kernel`.

Now that you are familiar with the topic, let's proceed to building kernel
modules. This article will guide you through the following steps:

1. Setting up a development environment with the necessary tools for building a
   kernel
2. Building an out-of-tree kernel
3. Building an in-tree kernel
4. Bonus: Creating a symbolic link to our NixOS configuration flake for easy
   reference to the kernel configuration used to build the system.

# Getting the development environment

Let's say you have your NixOS configured in `flake.nix` like this:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      my-nixos = nixpkgs.lib.nixosSystem {
       system = "x86_64-linux";
       modules = [ ./configuration.nix ];
     };
    };
  };
}
```

Let’s assume your NixOS flake is in `/etc/nixos`. To get a development shell
that has all the required dependencies for building a kernel and kernel modules,
you can run the command below. It will add a C compiler and some libraries
needed for compiling to your shell.

```command
$ nix develop "/etc/nixos#nixosConfigurations.my-nixos.config.boot.kernel"
```

# Let's build a kernel module with that!

Apart from the shell, we will also need the kernel development headers to build
a kernel module. They can be found in `boot.kernelPackages.kernel.dev`.

Let’s clone an example kernel module and build it:

```command
nix-shell> KERNELDIR=$(nix build --print-out-paths "/etc/nixos/#nixosConfigurations.turingmachine.config.boot.kernelPackages.kernel.dev")
nix-shell> git clone https://github.com/Mic92/uptime_hack/
nix-shell> cd uptime_hack
nix-shell> make -C $KERNELDIR/lib/modules/*/build M=$(pwd)
make: Entering directory '/nix/store/i7ph759bmlgrlkbz4dj5bjbbq47gx5nw-linux-6.0.12-dev/lib/modules/6.0.12/build'
  CC [M]  /home/joerg/git/uptime_hack/uptime_hack.o
  MODPOST /home/joerg/git/uptime_hack/Module.symvers
  CC [M]  /home/joerg/git/uptime_hack/uptime_hack.mod.o
  LD [M]  /home/joerg/git/uptime_hack/uptime_hack.ko
  BTF [M] /home/joerg/git/uptime_hack/uptime_hack.ko
Skipping BTF generation for /home/joerg/git/uptime_hack/uptime_hack.ko due to unavailability of vmlinux
make: Leaving directory '/nix/store/i7ph759bmlgrlkbz4dj5bjbbq47gx5nw-linux-6.0.12-dev/lib/modules/6.0.12/build'
```

# In-of-tree kernel modules

We can also use this algorithm to build in-tree kernel drivers.

Next, we’ll need to unpack the current kernel source and copy the kernel
configuration file to our unpacked Linux tree. The current kernel source is
stored in `$src` in the shell provided by `nix develop`. We can unpack the
kernel like this:

```command
$ tar -xvf "$src"
$ cd linux-*
```

Then, the Linux kernel configuration is stored in `.config`. We can copy this
file from the kernel.dev package to our unpacked Linux tree:

```command
$ cp $KERNELDIR/lib/modules/*/build/.config .config
```

Next, we will compile the kernel modules. But before, we need to prepare the
build environment for building kernel modules:

```command
$ make scripts prepare modules_prepare
```

Now, let’s build the new `null_blk` block device driver like this:

```command
$ make -C . M=drivers/block/null_blk
```

# Making your nixos closure refer the closure it was build from

If we actually want to insert any of those drivers into the **running** system,
the kernel in the NixOS configuration needs to be the same as the kernel of the
booted system. So, it makes sense to check and compare the kernel versions,
which you can do like this

```command
$ nix build --print-out-paths "/etc/nixos/#nixosConfigurations.my-nixos.config.boot.kernelPackages.kernel"
/nix/store/yyz5jkjsan9q7v8aa4i7697rrivzwmjz-linux-6.0.12
$ realpath /run/booted-system/kernel
/nix/store/yyz5jkjsan9q7v8aa4i7697rrivzwmjz-linux-6.0.12/bzImage
```

In this case, the paths match because I have not updated my Linux kernel since I
rebooted.

However, there is an even better way to replace the drivers with the new ones:
by adding a symlink of our NixOS flake to our NixOS system. This way, we will
always be able to refer to the flake at boot time.

How can you make NixOS closure contain a symlink to its own configuration flake?
By adding extra lines to `system.extraSystemBuilderCmds` like this:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      my-nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          # This will add a symlink in your nixos closure
          {
            system.extraSystemBuilderCmds = ''
              ln -s ${self} $out/flake
            '';
          }
        ];
      };
    };
  };
}
```

After a reboot, we can check the symlink was added by looking at
`/run/booted-system/flake`:

```command
$ ls -la /run/booted-system/flake
lrwxrwxrwx 2 root root 50 Jan  1  1970 /run/booted-system/flake -> /nix/store/mpqvkfdn46c8b3sd4zcg2fm0y4nsya8v-source
```

Now you can refer to your NixOS configuration like this…

```command
$ nix develop "$(realpath /run/booted-system/flake)#nixosConfigurations.$(hostname).config.boot.kernelPackages.kernel"
```

… and never have to wonder if your system is still in sync with your
configuration.

## Conclusion

Because things in NixOS are different from what we are used to in regular Linux
distributions, hacking a kernel needs some special attention. In this tutorial,
I shared my experience of hacking the NixOS kernel.

For quicker iterations on building kernels, also check out the
[nixos wiki article](https://nixos.wiki/wiki/Kernel_Debugging_with_QEMU) that
describes how to debug the Linux kernel with Qemu in NixOS.
