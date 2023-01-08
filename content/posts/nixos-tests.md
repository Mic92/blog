---
title: "Use NixOS tests in your own flakes"
date: 2023-01-08T11:46:06+01:00
categories: [ "nixos" ]
---

In this article, I will explain how you can leverage the NixOS testing framework
for full integration tests of nixos modules in your own projects outside of
the nixpkgs repository.

In NixOS we have a great test-framework that spawns one or more virtual machines
based on provided NixOS modules. In addition to the virtual machine definitions
this framwork also takes a snippet of python code that tests if the virtual
machine actually reach there desired state. NixOS tests are a great and fast way
to provide end-to-end integration testing close on how the application would run
in an production environment. They are therefore good at catching regressions
like incompatible configuration that might occure after an upgrade.

While this test framework is easy to use from within nixpkgs, there is still a
documentation gap on how we can import it from outside of nixpkgs, which is what
this article tries to address.

In the rest of the article, we will explore:
1. how to efficiently use this interface with flakes, 
2. followed by some tipps and tricks on how to access the virtual machines
   interactivily for troubleshooting.

# Defining nixos tests in your flake

If you never written any NixOS test, you can follow the 
[manual chapter](nixos/doc/manual/development/writing-nixos-tests.section.md) 
to get familiar with its structure. For a long time there was no official stable
API to load the testing framework into your own projects outside of nixpkgs.
This has changed thanks to [roberth]() who has created new interface to it.

Let's consider you have a project with the following `flake.nix` file, that
exposes a nixos module to run a simple webserver serving a hello-world website:


```nix
# flake.nix
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs, ...}: {
    nixosModules.hello-world-server = import ./hello-world-server.nix {};
  };
}
```

The definition of the hello-world server could look like this (saved as `./hello-world-server.nix`):

```nix
# hello-world-server.nix
{ pkgs, ... }:
let
  hello-world-server = pkgs.runCommand "hello-world-server" ''
    mkdir -p $out/{bin,/share/webroot}
    cat > $out/share/webroot/index.html <<EOF
    <html><head><title>Hello world</title></head><body><h1>Hello World!</h1></body></html>
    EOF
    cat > $out/bin/hello-world-server <<EOF
    #!${pkgs.runtimeShell}
    exec ${pkgs.lib.getExe pkgs.python3} -m http.server 8000 --dir "$out"
    EOF
    chmod +x $out/bin/hello-world-server
  '';
in {
  systemd.services.hello-world-server = {
    serviceConfig = {
      DynamicUser = true;
      ExecStart = lib.getExe hello-world-server;
    };
  };
}
```

Now that we have our nixos module, let's write a nixos test. 
It will use this module and than check if we can reach our hello world application.
To expose the test in our flake, we will add an attribute under the `checks` output of our flake.
This will make the test run when executing the `nix flake check -L` command.

```nix
# flake.nix
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs, ...}: let
    # expose systems for `x86_64-linux` and `aarch64-linux`
    forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
  in {
    nixosModules.hello-world-server = import ./hello-world-server.nix {};
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
    };
  };
}
```

Before defining the test, we also will use this little helper function that we
can use accross different nixos tests defined in our flake. The helper function
will import the test framework from nixpkgs and also passthru any inputs and
outputs defined in our flake by extending `specialArgs`.
Save it as `./tests/lib.nix`:

```nix
# tests/lib.nix
# The first argument to this function is the test module itself
test:
# Those arguments are provided `flake.nix` on import, see checkArgs
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
  # This is useful for referencing modules or packages from your own flake as well as importing
  # from other flakes.
  node.specialArgs = { inherit self; };
  imports = [ test ];
}).config.result
```

Next on the actual test itself that tests our service (`./tests/hello-world-server.nix`):

```nix
# ./tests/hello-world-server.nix
(import ./lib.nix) {
  name = "from-nixos";
  nodes = {
    # self here is set by using specialArgs in `lib.nix`
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

To verify that everything works. Run:

```console
$ nix flake check -L
# TODO shell output
```

The `-L` parameter here will make the build output all logs that happens during
the test to make it easier to follow.

So far so good. Our nixos module now has a proper test.
For more complex real-world example you might however sometimes struggle to understand,
why a test is not behaving properly.
This brings us to the second part on how to interactively execute nixos tests.

# Interactivly executing NixOS tests

When we run `nix flake check`, nix will run the so called test driver in its own build sandbox.
The test driver provides an API for the test script to setup virtual machines, followed
by a series of tests to check if the nixos modules are functioning as intended.
However it is also possible to start the test driver in a python `REPL`, which gives
us an interactive shell where we can execute our code instead of the test script.
This provides a great way to shorten the feedback loop as we execute commands on
our virtual machines i.e. to dump logs or to check the content of files.

To start our `hello-world-server` in interactive mode instead, we first need to
build the test driver and than start it manually by also providing the
`--interactive` flag.

```
# Here we assume that our test machine is running on `x86_64-linux`, adjust this to your own architecture)
$ nix build .#check.x86_64-linux
```

This will write out `result` symlink pointing to the test driver that we can run like this:

```
./result/bin/nixos-test-driver --interactive
```

Note that running the nixos test this way will also potentially allow the
virtual machine to access the internet. This might make some services work that
where failing before in the nix build sandbox.
Inside the REPL we can type out the python commands where defining in `testScript` before.
However we will get intermediate feedback and code completion for faster iteration cycles:

```
>>> node1.wait_for_unit("hello-world-server")
```

The API of the test driver also gives us direct shell access. The function
`<yourmachine>.shell_interact()` gives access to a shell running inside the
guest. Replace `<yourmachine` with the name of a virtual machine defined in the
the test i.e. `node1`:

```py
>>> node1.shell_interact()
node1: Terminal is ready (there is no initial prompt):
$ hostname
node1
```

For complex tests we may however rely on certain test code to be execute and only
inspect the virtual machine after a certain step in execution.
Here it comes handy to use the `breakpoint()` function in our test script and run the `test-driver` without `--interactive` flag:

```
# shortend example ./tests/hello-world-server.nix from above
(import ./lib.nix) {
  # ...
  testScript = ''
    start_all()
    node1.wait_for_unit("hello-world-server")
    output = node1.succeed("curl localhost:8000/index.html")
    # Test test will stop at this line giving back control to the user.
    breakpoint()
    assert "Hello world" in output, f"'{output}' does not contain 'Hello world'"
  '';
}
```

```
$ nix build .#check.x86_64-linux.hello-world-server
$ ./result/bin/nixos-test-driver
>>> print(output)
>>> node1.execute("systemctl status hello-world-server")
```

That's all for today.

## Conclusion
