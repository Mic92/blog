---
title: "Nix-ld: A clean solution for issues with pre-compiled executives on Nixos"
date: 2022-12-31T07:37:57+01:00
categories: [ "nixos", "kernel" ]
---
*No such file or directory: How I stopped worrying and started loving binaries on NixOS.*

In this article, I will discuss the technical issue of running pre-compiled
executables on NixOS, and how we can improve the user experience 
by making these binaries work seamlessly using [nix-ld](https://github.com/Mic92/nix-ld).

One of the key benefits of [NixOS](https://nixos.org/) is its focus on purity
and reproducibility. The operating system is designed to ensure that the system
configuration and installed software are always in a known and predictable
state. This is achieved through the use of the Nix package manager, which allows
users to declaratively specify their system configuration and software
dependencies.

However, this focus on purity can make it difficult for users to run
pre-compiled executables that were not specifically designed for NixOS. These
executables may have dependencies on libraries that are not available in the Nix
package manager, or may require patching or modification to work correctly on
the operating system.


##  The problem

If you have used NixOS for a while, you may have encountered an issue when attempting to run a pre-compiled executable. You probably saw something like this:

```command
$ ./masterpdfeditor5
bash: ./masterpdfeditor5: No such file or directory
```

However, the file clearly exists:

```command
$ ls -la ./masterpdfeditor5
-rwxr-xr-x 1 joerg users 27160344 Jul  4 16:22 ./masterpdfeditor5
```

To understand what is going on, we need to look at what happens when an
executable is run on a Linux operating system. When the shell attempts to run a
program, it uses an
[execve](https://man7.org/linux/man-pages/man2/execve.2.html) system call to
request the operating system to run the program. We can use the tool
[strace](https://strace.io/) to visualize this:


```command
$ strace -f ./masterpdfeditor5
execve("./masterpdfeditor5", ["./masterpdfeditor5"], 0x7fff70350ef8 /* 188 vars */) = -1 ENOENT (No such file or directory)
strace: exec: No such file or directory
+++ exited with 1 +++
```

`Strace` prints out the system call and its arguments, as well as the return
code from the operating system. In this case, we can see that bash derived its
error message (`No such file or directory`) from the `execve` system call.

To understand why the operating system is reporting this error, we need to
analyze the executable file further. The [file](https://man7.org/linux/man-pages/man1/file.1.html) command from the binutils package
provides more information about the executable file:

```command
$ file ./masterpdfeditor5
masterpdfeditor5: ELF 64-bit LSB executable, x86-64, version 1 (GNU/Linux), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, for GNU/Linux 2.6.32, BuildID[sha1]=406f865023e33cc6a0f9d179cc14a939c4b29fbe, stripped
```

We can see that the executable is a dynamically linked ELF binary that depends
on libraries found on the system to function. It uses a link-loader program,
also known as an `interpreter` to locate and load these libraries.

Commonly these programs are provided in your system libc, which in most cases is
[glibc](https://www.gnu.org/software/libc/), and are in a fixed location 
(`/lib64/ld-linux-x86-64.so.2` if your CPU is x86-based).

On NixOS, the issue with running pre-compiled executables arises because it
allows users to mix different libraries, including the glibc package. Unlike Linux, it does not provide a fixed path such as `/lib64/ld-linux-x86-64.so.2` for the
link-loader program. Executables packaged with Nix are linked against a specific
version of glibc. The [patchelf](https://github.com/Mic92/patchelf) command can be used to find out exactly which version is being used.

```command
$ patchelf --print-interpreter /run/current-system/sw/bin/ls
/nix/store/ayfr5l52xkqqjn3n4h9jfacgnchz1z7s-glibc-2.35-224/lib/ld-linux-x86-64.so.2
```

When the operating system tries to run an executable, it parses the binary and
looks for the specified link-loader. If it cannot find it, it returns the
generic error code `ENOENT`, which results in an unhelpful error message.

## The current solution

To work around this issue when packaging programs that do not have the source
code available, such as `masterpdfeditor`, Nix uses a build function called
`autoPatchelfHook` to analyze the binary and resolve any missing dependencies.

This function rewrites the interpreter path `/lib64/ld-linux-x86-64.so.2` to a
specific version of the glibc package, and populates the RPATH field in the
executable with paths to all necessary libraries for the program to run. The
link-loader uses this field to locate the libraries at runtime.

We can use the [patchelf](https://github.com/NixOS/patchelf) program to see the
effect of `autoPatchelfHook` on the `masterpdfeditor` program. By using
`nix-shell` to load a shell with masterpdfeditor and then printing the RPATH of
the program, we can see the paths to the necessary libraries encoded in the
program.

First, we load up a shell with masterpdfeditor in it.

```command
$ nix-shell -p masterpdfeditor
```

Next, we get the nix path to the program

```command
[nix-shell]$ which masterpdfeditor5
/nix/store/zmdjwbizg4a6cja4darcn2qy9imr336k-masterpdfeditor-5.8.70/bin/masterpdfeditor5
```

The next command prints the RPATH encoded in the program.

```command
[nix-shell]$ patchelf --print-rpath "/nix/store/zmdjwbizg4a6cja4darcn2qy9imr336k-masterpdfeditor-5.8.70/bin/.masterpdfeditor5-wrapped"
```

It gives this result:

```command
/nix/store/y4k2206qhks30wspxx1nkmgfqfdmxp0j-sane-backends-1.1.1/lib:/nix/store/zaflwh2nwzj1f0wngd7hqm3nvlf3yhsx-zlib-1.2.13/lib:/nix/store/dgxn688wq7whsvs2fycygq0wn888xnsv-qtsvg-5.15.7/lib:/nix/store/9lcgwnc70f4wj1czklczql7a
wcv24mi-qtbase-5.15.7/lib:/nix/store/lgfp5762m5qzby9syd21kj04l5qmjg4h-qtdeclarative-5.15.7/lib:/nix/store/ykjcsxdh9c1w664g6v38d86gph8m6mq7-libglvnd-1.5.0/lib:/nix/store/wprxx5zkkk13hpj6k1v6qadjylh3vq9m-gcc-11.3.0-lib/lib
```

While `autoPatchelfHook` is a useful tool for making many programs usable in Nix,
there are a few cases where it may not be possible or practical to use it. These include:

- Using binary executables downloaded with third-party package managers (e.g.
  vscode, npm, or pip). With autoPatchelfHook, these would have to be patched on every update
- Executables hidden inside other programs or archives, for example Java JARs might contain executables unpacked at runtime.
- Running a game or proprietary software that verifies its integrity and will not start if the binary has been modified.
- Programs that are too large to be copied to the Nix store (e.g. FPGA IDEs).

## Nix-ld to the rescue!

To address these cases, [nix-ld](https://github.com/Mic92/nix-ld) was created as an alternative to `autoPatchelfHook`. It allows users to run pre-compiled executables on NixOS without the need to modify the binaries or copy them to the Nix store. This improves the user experience by allowing users to easily run binaries downloaded from third-party sources and proprietary software without patching or modification.

It is installed in the same location as the link-loader on other Linux
distributions (i.e. `/lib64/ld-linux-x86-64.so.2`), and it loads the actual
link-loader as specified in the `NIX_LD` environment variable. It also accepts a
comma-separated list of library lookup paths in `NIX_LD_LIBRARY_PATH` and
rewrites this variable to `LD_LIBRARY_PATH` before passing execution to the
link-loader. This allows users to specify additional libraries that the
executable needs to run.

On a system configured with `nix-ld`, the error message when attempting to run
an unpatched binary will be more informative and provide guidance on how to
address the issue:

```command
$ ./masterpdfeditor5
cannot execute ./masterpdfeditor5: You are trying to run an unpatched binary on nixos, but you have not configured NIX_LD or NIX_LD_x86_64-linux. See https://github.com/Mic92/nix-ld for more details
```

To further improve the user experience, a new feature is available in the latest unstable version of NixOS and the upcoming 23.05 release. It allows the most common libraries to be included in the NixOs configuration as follows:

```
{ config, pkgs, ... }: {
  # Enable nix ld
  programs.nix-ld.enable = true;

  # Sets up all the libraries to load
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    fuse3
    icu
    zlib
    nss
    openssl
    curl
    expat
    # ...
  ];
}
```

For a more extensive version of this configuration, see my [dotfiles](https://github.com/Mic92/dotfiles/blob/master/nixos/modules/nix-ld.nix).

By including the most common libraries in the configuration, nix-ld can provide
a more seamless experience for users running pre-compiled executables on NixOS. They will not need to manually specify the necessary libraries for each
executable and can simply run them as they would on other Linux distributions.

## Conclusion

In conclusion, nix-ld is a useful tool for running pre-compiled executables on
NixOS without the need for patching or modification. It provides a shim layer
that allows users to specify the necessary libraries for each executable and
improves the user experience by allowing users to easily run binaries from
third-party sources and proprietary software. By including the most common
libraries in the NixOS configuration, nix-ld can provide an even more seamless
experience for running pre-compiled executables on NixOS. 

In my next article, I’ll be looking at a similar issue to the one encountered when working with executable binaries. Scripts that are hardcoded to point to /usr/bin can also cause a problem on NixOS, and I will address this by introducing [envfs](https://github.com/Mic92/envfs)
