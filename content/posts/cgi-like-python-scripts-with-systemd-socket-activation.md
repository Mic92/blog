+++
title = "Cgi Like Python Scripts With Systemd Socket Activation"
date = "2015-06-25"
slug = "2015/06/25/cgi-like-python-scripts-with-systemd-socket-activation"
Categories = []
+++

Lets say you want to trigger remote the start of a python script.
But you don't want to have a service running all the time waiting for requests.

What you can do, is using socket-unit in systemd, which is waiting on a tcp port for connections
and starts the service, if somebody is requesting it.

The systemd configuration could look like this:

- Listens on tcp port 3000 (both ipv4 and ipv6)
- Execute python script as user 'nobody' with a timeout of 5 minutes

```systemd
[Unit]
Description=Start update on demand

[Socket]
ListenStream=3000
# only listen on localhost
#ListenStream=127.0.0.1:3000
BindIPv6Only=both

[Install]
WantedBy=multi-user.target
```

```systemd
[Unit]
Description=Start update on demand
JobTimeoutSec=5min

[Service]
User=nobody
ExecStart=/usr/bin/python /path/to/script.py
```

In your python code, do the following

```python
def systemd_socket_response():
    """
    Accepts every connection of the listen socket provided by systemd, send the
    HTTP Response 'OK' back.
    """
    try:
        from systemd.daemon import listen_fds;
        fds = listen_fds()
    except ImportError:
        fds = [3]

    for fd in fds:
        import socket
        sock = socket.fromfd(fd, socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(0)

        try:
            while True:
              conn, addr = sock.accept()
              conn.sendall(b"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 3\r\n\r\nOK\n")
        except socket.timeout:
            pass
        except OSError as e:
            # Connection closed again? Don't care, we just do our job.
            print(e)

if __name__ == "__main__":
   if os.environ.get("LISTEN_FDS", None) != None:
        systemd_socket_response()
   # here your own code begins
   do_work()
```

This still lacks of authentication and does not take any arguments.
You could protect this port using a frontend webserver with http authentication,
or you pass the listen socket to an python http server, which add some token
passed authentication. Systemd will ensure, that your service will not run more
than once at the time.
