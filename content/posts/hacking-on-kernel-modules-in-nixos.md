---
title: "Hacking on Kernel Modules in NixOS"
date: 2022-12-17T20:50:21+01:00
categories: [ "nixos", "kernel" ]
---

Lately I hacked on some kernel modules to get more debug logs out of a kernel
module on my NixOS machine. Commonly linux distributions put their kernel
sources in `/usr/src` and their kernel modules in `/lib/modules/$(uname -r)`.
Like always, NixOS is a special snowflake. However once you get to learn the
mechanics, it is actually quite pleasant to use.

In the NixOS configuration the kernel is defined via the option
`boot.kernelPackages`. `kernelPackages` not only defines the kernel, but also
all out-of-tree kernel modules and other packages that have the kernel as a
build dependency. The actual linux kernel is accessible in `boot.kernelPackages.kernel`.

Let's say you have your NixOS configured in `flake.nix` like this:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      my-nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
        ];
      };
    };
  };
}
```

To get a development shell that has all dependencies for building a kernel and kernel modules, you can run the below:

```command
$ nix develop "/etc/nixos#nixosConfigurations.my-nixos.config.boot.kernel"
```

The above example assumes your NixOS flake is in `/etc/nixos`.

The command will add a C compiler and some libraries needed for compiling to your shell.

So, let's build a kernel module with that!
For this we will also need the kernel development headers found at:
`boot.kernelPackages.kernel.dev`.

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

We can also use this for in-tree kernel drivers.

The shell provided by `nix develop` has the current kernel source stored in `$src` that we can unpack like this:

```command
$ tar -xvf "$src"
$ cd linux-*
```

The linux kernel configuration is stored in `.config`.
We can copy this file from the kernel.dev package to our unpacked linux tree:

```command
$ cp $KERNELDIR/lib/modules/*/build/.config .config
```

Before we can compile kernel modules, we also need to generate some more files as required by the kernel build system:

```command
$ make scripts prepare modules_prepare
```

This example builds the `null_blk` block device driver:

```command
$ make -C . M=drivers/block/null_blk
```

If we actually want to insert any of those drivers into the running system, the
kernel in the NixOS configuration needs to be the same as kernel as the booted
system:

```command
$ nix build --print-out-paths "/etc/nixos/#nixosConfigurations.my-nixos.config.boot.kernelPackages.kernel"
/nix/store/yyz5jkjsan9q7v8aa4i7697rrivzwmjz-linux-6.0.12
$ realpath /run/booted-system/kernel
/nix/store/yyz5jkjsan9q7v8aa4i7697rrivzwmjz-linux-6.0.12/bzImage
```

In this case it matches because I have not updated my linux kernel since I rebooted.
However there is an even better way: By adding a symlink of our NixOS flake to our NixOS system,
we can make sure that we can always refer to the flake at the time of boot:

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

After adding the extra lines to `system.extraSystemBuilderCmds` the NixOS closure will contain a symlink to its own configuration flake.
Afer a reboot, we can inspect this at `/run/booted-system/flake`:

```command
$ ls -la /run/booted-system/flake
lrwxrwxrwx 2 root root 50 Jan  1  1970 /run/booted-system/flake -> /nix/store/mpqvkfdn46c8b3sd4zcg2fm0y4nsya8v-source
```

Now you can refer to your NixOS configuration like this...

```command
$ nix develop "$(realpath /run/booted-system/flake)#nixosConfigurations.$(hostname).config.boot.kernelPackages.kernel"
```

... and never have to worry and wonder if your system is still in sync with your configuration.

## Conclusion

Because NixOS does not follow the FHS standard for filesystem layouts, the
standard kernel hacker tutorials won't fully apply to NixOS. However, by
leveraging the NixOS configuration we can quickly set up an environment that
allows us to compile the linux kernel and its modules.
