---
title: "Use NixOS tests in your own flakes"
date: 2023-01-08T11:46:06+01:00
categories: [ "nixos" ]
---

This article explains how to utilize the NixOS testing framework to perform full
integration tests on nixos modules in your own projects outside of the nixpkgs
repository.

In NixOS we have a great test-framework, allows you to create one or more
virtual machines based on specific NixOS modules and test their desired state
using a snippet of Python code. These tests provide end-to-end integration
testing and are useful for catching regressions and incompatible configurations
that may occur after an upgrade. 

While the testing framework is easy to use within nixpkgs, there is currently a
lack of documentation on how to use it from outside of nixpkgs. In the article,
we will cover how to use this interface with flakes and provide tips and tricks
for accessing the virtual machines interactively for troubleshooting.

# Defining nixos tests in your flake

To define nixos tests in your flake, you can refer to the [manual chapter](https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/development/writing-nixos-tests.section.md)
on writing nixos tests to understand the structure. 

Previously, there was no stable API to import the testing framework into
projects outside of nixpkgs, but this has changed thanks to
[Robert Hensing](https://github.com/NixOS/nixpkgs/pull/191540) who created a new modular
interface for it. 

As an example, let's say you have a project with a `flake.nix` file that exposes
a nixos module to run a simple web server serving a hello world website:

```nix
# flake.nix
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs, ...}: {
    nixosModules.hello-world-server = import ./hello-world-server.nix {};
  };
}
```

The definition of the hello-world-server nixos module can be found in `./hello-world-server.nix`:

```nix
# hello-world-server.nix
{ pkgs, lib, ... }:
let
  hello-world-server = pkgs.runCommand "hello-world-server" {} ''
    mkdir -p $out/{bin,/share/webroot}
    cat > $out/share/webroot/index.html <<EOF
    <html><head><title>Hello world</title></head><body><h1>Hello World!</h1></body></html>
    EOF
    cat > $out/bin/hello-world-server <<EOF
    #!${pkgs.runtimeShell}
    exec ${lib.getExe pkgs.python3} -m http.server 8000 --dir "$out/share/webroot"
    EOF
    chmod +x $out/bin/hello-world-server
  '';
in {
  systemd.services.hello-world-server = {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      DynamicUser = true;
      ExecStart = lib.getExe hello-world-server;
    };
  };
}
```

Now that we have our nixos module, we can write a nixos test to check if we can
reach the "hello world" application. To expose the test in our flake, we will
add an attribute under the `checks` output in the `flake.nix` file. This will make
the test run when you execute the `nix flake check -L` command. The test uses the
hello-world-server nixos module and checks if the application can be reached.

```nix
# flake.nix
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs, ...}: let
    # expose systems for `x86_64-linux` and `aarch64-linux`
    forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
  in {
    nixosModules.hello-world-server = import ./hello-world-server.nix;
    checks = forAllSystems (system: let
      checkArgs = {
        # reference to nixpkgs for the current system
        pkgs = nixpkgs.legacyPackages.${system};
        # this gives us a reference to our flake but also all flake inputs
        inherit self;
      };
    in {
      # import our test
      hello-world-server = import ./tests/hello-world-server.nix checkArgs;
    });
  };
}
```

Before defining the test, we will also use a helper function that can be used
across different nixos tests defined in our flake. This helper function will
import the test framework from nixpkgs and pass through any inputs and outputs
defined in our flake by extending `specialArgs`. Save it as `./tests/lib.nix`:

```nix
# tests/lib.nix
# The first argument to this function is the test module itself
test:
# These arguments are provided by `flake.nix` on import, see checkArgs
{ pkgs, self}:
let
  inherit (pkgs) lib;
  nixos-lib = import (pkgs.path + "/nixos/lib") {};
in
(nixos-lib.runTest {
  hostPkgs = pkgs;
  # optional to speed up to evaluation by skipping evaluating documentation
  defaults.documentation.enable = lib.mkDefault false;
  # This makes `self` available in the nixos configuration of our virtual machines.
  # This is useful for referencing modules or packages from your own flake 
  # as well as importing from other flakes.
  node.specialArgs = { inherit self; };
  imports = [ test ];
}).config.result
```

This is the actual test that tests the hello-world-server service (`./tests/hello-world-server.nix`):

```nix
# ./tests/hello-world-server.nix
(import ./lib.nix) {
  name = "from-nixos";
  nodes = {
    # `self` here is set by using specialArgs in `lib.nix`
    node1 = { self, pkgs, ... }: {
      imports = [ self.nixosModules.hello-world-server ];
      environment.systemPackages = [ pkgs.curl ];
    };
  };
  # This is the test code that will check if our service is running correctly:
  testScript = ''
    start_all()
    # wait for our service to start
    node1.wait_for_unit("hello-world-server")
    output = node1.succeed("curl localhost:8000/index.html")
    # Check if our webserver returns the expected result
    assert "Hello world" in output, f"'{output}' does not contain 'Hello world'"
  '';
}
```

To verify that everything works, run:

```console
$ nix flake check -L
start all VLans
start vlan
running vlan (pid 7; ctl /build/vde1.ctl)
(finished: start all VLans, in 0.00 seconds)
run the VM test script
additionally exposed symbols:
    node1,
    vlan1,
    start_all, test_script, machines, vlans, driver, log, os, create_machine, subtest, run_tests, join_all, retry, serial_stdout_off, serial_stdout_on, polling_condition, Machine
start all VMs
node1: starting vm
node1: waiting for monitor prompt
node1 # Formatting '/build/vm-state-node1/node1.qcow2', fmt=qcow2 cluster_size=65536 extended_l2=off compression_type=zlib size=1073741824 lazy_refcounts=off refcount_bits=16
(finished: waiting for monitor prompt, in 0.02 seconds)
node1: QEMU running (pid 8)
(finished: start all VMs, in 0.05 seconds)
node1: waiting for unit hello-world-server
node1: waiting for the VM to finish booting
...
(finished: waiting for unit hello-world-server, in 7.02 seconds)
node1: must succeed: curl localhost:8000/index.html
node1 #   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
node1 #                                  Dload  Upload   Total   Spent    Left  Speed
node1 #   0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0[    6.668081] hello-world-server[824]: 127.0.0.1 - - [08/Jan/2023 19:59:47] "GET /index.html HTTP/1
.1" 200 -
node1 # 100    87  100    87    0     0   4034      0 --:--:-- --:--:-- --:--:--  4350
(finished: must succeed: curl localhost:8000/index.html, in 0.07 seconds)
(finished: run the VM test script, in 7.15 seconds)
test script finished in 7.18s
cleanup
kill machine (pid 8)
node1 # qemu-kvm: terminating on signal 15 from pid 6 (/nix/store/al6g1zbk8li6p8mcyp0h60d08jaahf8c-python3-3.10.9/bin/python3.10)
(finished: cleanup, in 0.04 seconds)
kill vlan (pid 7)
```

The `-L` parameter here will make the build output all logs that occur during
the test, making it easier to follow.

Our `hello-world-server` nixos module now has a proper test. For more complex,
real-world examples, you may sometimes struggle to understand why a test is not
behaving properly. This brings us to the second part on how to interactively
execute nixos tests.

# Interactivly executing NixOS tests

When we run `nix flake check`, nix will run the so called test driver in its own build sandbox.
The test driver provides an API for the test script to setup virtual machines, followed
by a series of tests to check if the nixos modules are functioning as intended.
However it is also possible to start the test driver in a python `REPL`, which gives
us an interactive shell where we can execute our code instead of the test script.
This provides a great way to shorten the feedback loop as we execute commands on
our virtual machines i.e. to dump logs or to check the content of files.


When you run `nix flake check`, nix will run the test driver in its own build
sandbox. The test driver provides an API for the test script to set up virtual
machines and run a series of tests to check if the nixos modules are functioning
as intended. However, it is also possible to start the test driver in a python
REPL, which gives you an interactive shell where you can execute your code
instead of the test script. This provides a great way to shorten the feedback
loop as you can execute commands on the virtual machines to check logs or the
content of files.

To start the `hello-world-server` test in interactive mode, you first need to
build the test driver and then start it manually by providing the `--interactive`
flag.

```console
# Here we assume that our test machine is running on `x86_64-linux`, adjust this to your own architecture)
$ nix build .#check.x86_64-linux
```

This will write out `result` symlink pointing to the test driver that we can run like this:

```console
$ ./result/bin/nixos-test-driver --interactive
```

Note that running the nixos test this way will also potentially allow the
virtual machine to access the internet, which may make some services work that
were failing before in the nix build sandbox. Inside the REPL, you can type out
the python commands defined in `testScript`, but you will get intermediate
feedback and code completion for faster iteration cycles.

For example:

```console
>>> node1.wait_for_unit("hello-world-server")
```

The API of the test driver also gives you direct shell access. The function
`<yourmachine>.shell_interact()` gives you access to a shell running inside the
guest. Replace `<yourmachine>` with the name of a virtual machine defined in the
test, i.e. `node1`.

This is how the article ends:

```py
>>> node1.shell_interact()
node1: Terminal is ready (there is no initial prompt):
$ hostname
node1
```

For complex tests, you may need to execute certain test code and only inspect
the virtual machine after a certain step in execution. In these cases, you can
use the `breakpoint()` function in your test script and run the test-driver
without the `--interactive` flag:

```nix
# shortend example ./tests/hello-world-server.nix from above
(import ./lib.nix) {
  # ...
  testScript = ''
    start_all()
    node1.wait_for_unit("hello-world-server")
    output = node1.succeed("curl localhost:8000/index.html")
    # Test will stop at this line, giving you control.
    breakpoint()
    assert "Hello world" in output, f"'{output}' does not contain 'Hello world'"
  '';
}
```

```console
$ nix build .#check.x86_64-linux.hello-world-server
$ ./result/bin/nixos-test-driver
>>> print(output)
>>> node1.execute("systemctl status hello-world-server")
```

## Conclusion

In this article, we explained how you can leverage the NixOS testing framework
for full integration tests of nixos modules in your own projects outside of the
nixpkgs repository. We demonstrated how to define a nixos test in a flake and
exposed it through the checks output, making it run when executing the `nix
flake check -L` command.  We also showed how you can interactively execute nixos
tests to troubleshoot and debug complex tests, using either the `--interactive`
flag or breakpoints in your test script. By using these techniques, you can
improve the quality and reliability of your nixos modules and ensure that they
are functioning correctly.
