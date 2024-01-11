---
title: "How to use NixOS testing framework with flakes"
date: 2023-01-08T11:46:06+01:00
categories: ["nixos"]
author: "Jörg Thalheim and Alex A. Renoire"
---

In this article, I will explain how to perform full integration tests with
flakes outside nixpkgs.

With [NixOS testing framework](https://nixos.wiki/wiki/NixOS_Testing_library),
you can
[create end-to-end integration tests](https://nix.dev/tutorials/integration-testing-using-virtual-machines)
easily. It all comes down to starting a virtual machine based on your custom
modules and testing its state with a Python script. This way, you can identify
in advance all the regressions and incompatible configurations arising from the
updates you introduced.

One of the framework's upsides is that it's extremely fast — maybe the fastest
of its kind: setting up VMs and running tests does not take much time thanks to
sharing files with the nix store on the host.

But previously, there was no stable API to import the testing framework into
projects, therefore it was hard to test anything that's outside NixOS. The
situation has changed thanks to Robert Hensing, who [created a new modular
interface] for testing.

But there's still a problem with documentation. Of course, you can refer to the
corresponding
[manual chapter](https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/development/writing-nixos-tests.section.md)
to explore NixOS testing framework. But many topics aren't explained in detail,
so I decided to write a brief intro to testing NixOS modules with flakes.

# Intro to testing in NixOS

Let me give you some info on how tests are executed, and how to incorporate them
into your project. If you're new to NixOS, this info may be helpful.

So, how are tests executed in NixOS? To verify that the flake can be evaluated
successfully, we run the
[flake check](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake-check.html)
command. Under the hood, nix will run the so-called test driver in its own build
sandbox. The test driver provides an API for the test script to setup virtual
machines. When the VMs are ready, a series of tests are executed to check if
NixOS modules are functioning as intended.

That's a very broad outlook on how tests work. But how do you write tests?
First, if you are testing a module outside NixOS, i.e. in your own project, you
have to import `nixpkgs`, the biggest repository of Nix packages where the
testing library is located.

There are several ways to import `nixpkgs` in your code. One way is via
`fetchTarball`:

```nix
{
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/archive/....tar.gz";
  pkgs = import nixpkgs {};
}
```

But `fetchTarball` is a builtin, which means that `nixpkgs` will be downloaded
during evaluation. Another way is to load `nixpkgs` using a
[flake](https://nixos.wiki/wiki/Flakes). It's more convenient, because this way
you can update the dependencies easily. I'll use this approach in my example.

Let's move to the coding part now.

# Defining a flake to be tested

As an example, I’ll take a simple project that runs a web server returning a
“Hello world!” string. First, let’s specify the flake:

```nix
# flake.nix
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs, ...}: {
    nixosModules.hello-world-server = import ./hello-world-server.nix {};
  };
}
```

This flake exposes the module `./hello-world-server.nix`. You can find the file
in the repository [here](https://github.com/Mic92/nixos-test-example). What it
does is it creates a simple HTML page and starts a server on the port 8000. The
correct behavior would be if the module returns a “Hello world!” string. Any
other output will be incorrect.

# Writing the tests

Now that we have our flake and module, we can write a test to check if we can
reach the server.

But before that, we will create a helper function in `./tests/lib.nix`, which
will import the testing framework from nixpkgs. Extending `specialArgs` will
allow us to pass through any flake inputs and outputs.

```nix
# tests/lib.nix
# The first argument to this function is the test module itself
test:
# These arguments are provided by `flake.nix` on import, see checkArgs
{ pkgs, self}:
let
  inherit (pkgs) lib;
  # this imports the nixos library that contains our testing framework
  nixos-lib = import (pkgs.path + "/nixos/lib") {};
in
(nixos-lib.runTest {
  hostPkgs = pkgs;
  # This speeds up the evaluation by skipping evaluating documentation (optional)
  defaults.documentation.enable = lib.mkDefault false;
  # This makes `self` available in the NixOS configuration of our virtual machines.
  # This is useful for referencing modules or packages from your own flake
  # as well as importing from other flakes.
  node.specialArgs = { inherit self; };
  imports = [ test ];
}).config.result
```

You can use this helper function across different NixOS tests in your project.

Now, let’s create the test:

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
    node1.wait_for_open_port(8000)
    output = node1.succeed("curl localhost:8000/index.html")
    # Check if our webserver returns the expected result
    assert "Hello world" in output, f"'{output}' does not contain 'Hello world'"
  '';
}
```

To expose the test in our flake, we will import it in the checks output in the
`flake.nix` file. This will make the test run when you execute the
`nix flake check -L` command.

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

Now that we have our nixos module, we can write a nixos test to check if we can
reach the "hello world" application. To expose the test in our flake, we will
add an attribute under the `checks` output in the `flake.nix` file. This will
make the test run when you execute the `nix flake check -L` command. The test
uses the hello-world-server nixos module and checks if the application can be
reached.

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

# Running the tests

To verify that everything works as expected, run:

```console
$ nix flake check -L
```

The -L parameter here tells the testing framework to print all logs that occur
during the test, making it easier to follow.

```console
start all VLans
...
start all VMs
...
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
...
```

Here, the testing framework creates a virtual network and a virtual machine with
our module in it, then it waits for the hello-world-server to start and checks
if its output is valid. Here, the output is “Hello world!”, so we passed the
test.

Now our hello-world-server NixOS module has a proper test!

# Conclusion

In this article, we explained how you can leverage the NixOS testing framework
for your projects while importing the nixpkgs repository. In particular, we
defined a NixOS test in a flake and exposed it through the checks output, making
it run when executing the `nix flake check -L` command.

But often you need to run your tests interactively to check the debug output and
gain more insight into why a test isn’t behaving the way you expected. That’s
what I explore in a [twin article]({{< ref "nixos-tests-2" >}}).
