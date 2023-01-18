# Source of my blog

Visit at https://blog.thalheim.io

## Work on the website

Clone this website:

```console
$ git clone https://github.com/Mic92/blog
```

Get all build dependencies:

``` shell
$ nix-shell
```

Through the [just](https://github.com/casey/just) command runner you can perform common task:

```console
$ just -l
Available recipes:
    build    # Build website
    fmt      # Format content
    new PAGE # Generate new blog post. i.e. hugo new posts/nix-ld.md
    serve    # Open local server for the blog
```

i.e. to run a server locally to view the website type:


```console
$ just serve
hugo server
Start building sites … 
...
Running in Fast Render Mode. For full rebuilds on change: hugo server --disableFastRender
Web Server is available at http://localhost:1313/ (bind address 127.0.0.1)
Press Ctrl+C to stop
```
