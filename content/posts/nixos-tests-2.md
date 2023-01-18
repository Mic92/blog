---
title: "How to execute NixOS tests interactively for debugging"
date: 2023-01-08T11:46:06+01:00
categories: ["nixos"]
author: ["Jörg Thalheim and Alex A. Renoire"]
---

For complex modules, you may sometimes struggle to understand why a test isn't
behaving properly. To gain more insight, you may want to check the debug output.
This leads me to discuss how to execute NixOS tests interactively.

# Problem statement

In a [standard way of running tests](nixos-tests.md), you can't interfere with
the process to explore what's gone wrong.

But there's a trick: you can start the test driver in a python REPL loop, which
will provide an interactive shell where you can execute your tests. This is a
great way to shorten the feedback loop, as we can execute commands on our VMs.
For instance, we can tell a VM to dump logs or to display the contents of files.

So, let's explore how to run tests interactively.

# Running tests interactively

To start the hello-world-server test in the interactive mode, you first need to
build the test driver and then start it manually by providing the
`--interactive` flag. Here's how you do it:

```console
# Here we assume that our test machine is running on `x86_64-linux`, adjust this to your own architecture)

$ nix build .#check.x86_64-linux
```

This will write out result symlink (all files are created in the nix store and
we don't want to copy them outside) pointing to the test driver. We can run the
test driver like this:

```console
./result/bin/nixos-test-driver --interactive
```

**Note:** _Usually when running tests there's no Internet access because you
want things to be reproducible and self-contained. Running NixOS tests this way
will allow the VM to access the Internet, which will make some services work
that didn't work previously in the nix build sandbox. Therefore, some tests will
pass that were failing previously._

Inside the REPL, you can type out the Python commands to test your module. For
example:

```python
>>> node1.wait_for_unit("hello-world-server")
```

## Direct shell access

The API of the test driver gives you direct shell access with
`<yourmachine>.shell_interact()`, so you can access the shell running inside the
guest machine.

To try it out, let's replace the placeholder with the name of the VM defined in
the test --- node1:

```py
>>> node1.shell_interact()
node1: Terminal is ready (there is no initial prompt):
$ hostname
node1
```

## Breakpoints

For complex modules, you may need to execute certain tests and only then inspect
the virtual machine. In such case, you can use the `breakpoint()` function in
your test script and run the test-driver without the `--interactive` flag:

```
# shortend example ./tests/hello-world-server.nix from above

(import ./lib.nix) {

 # ...

 testScript = ''

 start_all()

 node1.wait_for_unit("hello-world-server")

 output = node1.succeed("curl localhost:8000/index.html")

 # The test will stop at this line, giving you control over execution.

 breakpoint()

 assert "Hello world" in output, f"'{output}' does not contain 'Hello world'"

 '';

}
```

Here, we stopped the test flow and are looking at the value of `output` and
checking the status of the module with `systemctl`.

```console
$ nix build .#check.x86_64-linux.hello-world-server
$ ./result/bin/nixos-test-driver
>>> print(output)
>>> node1.execute("systemctl status hello-world-server")
```

# Conclusion

In this article, we showed how you can interactively execute NixOS tests for
easier troubleshooting and debugging. In short, you can do so using either the
`--interactive` flag or breakpoints in your test script. In comparison to
running tests in a sandbox, you can get immediate feedback and code completion,
and look at the intermediate results.

By employing these techniques, you can improve the quality and reliability of
your NixOS modules and ensure that they are functioning correctly.
