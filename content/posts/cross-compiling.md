+++
title = "Cross compiling and deploying NixOS"
date = "2022-11-27"
slug = "2022/11/27/nixos-cross-compiling"
Categories = [ "nix", "cross", "compiling" ]
author = ["Jörg Thalheim and Alex A. Renoire"]
+++

*Written by Jörg Thalheim and Alex A. Renoire*

## Background

Last week I was setting up this RISCv-based HiFive Unmatched board[1] with NixOS. Thanks to [zhaofengli](https://github.com/zhaofengli) this was actually pretty straight forward given that his [repository](https://github.com/zhaofengli/nixos-riscv64) contained a full walk-through, images and a binary cache. So instead of spending the [NixOS Munich Meetup](https://www.meetup.com/Munich-NixOS-Meetup/) hacking on this architecture, I had time to go further.

One of the thing that becomes quickly apparent while hacking on the board is that although the board is quite beefy with 16GB of RAM and NVME, it cannot keep up with up-to-date x86 machines. This is where cross-compiling NixOS helps.

## Goal of this article

In this article I will show you how to use NixOS on a host x86_64 machine to debug and cross-deploy another NixOS machine. And iterate faster doing so.

We're going to do this with the following steps:

1. How to define a cross-compiled nixos configuration in flakes
2. How to deploy from cross-compile nixos machine
3. Work-around cross-compiling issues with binfmt

## Configuring the flake

First we need to find out the architecture we want to build
on and the architecture to build for.
The easiest way to find out is using `nix repl`

```console
$ nix repl '<nixpkgs>'
repl> pkgs.system # This is our build architecture
"x86_64-linux"
# use tab completion to find the architecture you want to build for
repl> pkgsCross.<TAB>
```

We are interested in `pkgsCross.<arch>.system` here. For my board this looks like this:

```console
repl> pkgsCross.riscv64.system
"riscv64-linux"
```

With information we can define the cross-compiled variant of our nixos machine:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-22.11";

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      # Native machine build
      my-nixos = nixpkgs.lib.nixosSystem {
        system = "riscv64-linux";
        modules = [ ./configuration.nix ];
      };
      
      # Cross machine build, from x86_64
      my-nixos-from-x86_64 = nixpkgs.lib.nixosSystem {
        modules = [
          ./configuration.nix
          { 
            # This is the architecture we build from (pkgs.system from above) 
            nixpkgs.buildPlatform = "x86_64-linux";
            # pkgsCross.<yourtarget>.system
            nixpkgs.hostPlatform = "riscv64-linux";
          }
        ];
      };
    };
  };
}
```

## Deploying to the board

Now that we have this extended flake configuration, deploying the new system closures to the board becomes easy:

```console
$ nixos-rebuild switch \
  --fast \
  --build-host localhost \
  --target-host $target_host \
  --flake .#my-nixos-from-x86_64 
```

nixos-rebuild will (1) build the system on the host machine, and then (2) copy
the build result onto the board, and finally (3) atomically switch the
configuration.  The `--fast` flag here is crucial since it stops `nixos-rebuild`
from using the riscv build of nix on the x86_64 machine.

## (Bonus) Work-around cross-compiling issues with binfmt

While many packages cross-compile out-of-the box a few packages
are not aware of cross compiling and try to execute binaries
they just have built on the same machine.
Since it sometimes not feasiable to fix this issues easily,
one trick is to set platform emulation support based binfmt_misc
and qemu. This allows to run the binaries directly on the NixOS host
that are actually compiled for a different architecture.

It also allows to test and run binaries without having to 
copy them over to the target machine.

In order to do that, extend the host NixOS configuration

```nix
{
  boot.binfmt.emulatedSystems = [
    "riscv64-linux"
  ];
}
```

## Conclusion

Cross-compiling has made good progress over the years. While still not a
first-class citizen in nixpkgs is now in a usable state for deploying nixos
systems. This helps a lot to get NixOS on little computers and port Nix to new
architecture are not covered by official hydra builds.
