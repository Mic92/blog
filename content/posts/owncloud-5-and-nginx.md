+++
title = "Owncloud 5 and Nginx"
date = "2013-04-19"
slug = "2013/04/19/owncloud-5-and-nginx"
Categories = ["nginx", "owncloud"]
+++

Since my last [post](http://localhost:4000/2012/06/03/owncloud-4-and-nginx/)
owncloud has added
[offical documentation for nginx](http://doc.owncloud.org/server/5.0/admin_manual/installation/installation_others.html#nginx-configuration).
Unfortunately the documentation there didn't worked for me out of the box:

```plain error.log
2013/04/19 22:14:38 [error] 32402#0: *251 FastCGI sent in stderr: "Access to the
script '/var/www/cloud' has been denied (see security.limit_extensions)" while
reading response header from upstream,  client: ::1,  server:
cloud.higgsboson.tk,  request: "GET /index.php HTTP/1.1",  upstream:
"fastcgi://unix:/var/run/php-fpm.sock:",  host: "cloud.higgsboson.tk"
```

The problem here was again a missing fastcgi_params option.

To solve the problem include the following line either in
'/etc/nginx/fastcgi_params'

```nginx /etc/nginx/fastcgi_params
fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
# ...
```

or in the owncloud block in nginx.conf:

```nginx /etc/nginx/nginx.conf
server {
  listen 80;
  server_name cloud.example.com;
  return  https://$server_name$request_uri;  # enforce https
}

server {
  listen 443 ssl;
  server_name cloud.example.com;

  ssl_certificate /etc/ssl/nginx/cloud.example.com.crt;
  ssl_certificate_key /etc/ssl/nginx/cloud.example.com.key;

  # Path to the root of your installation
  root /var/www/;

  client_max_body_size 10G; # set max upload size
  fastcgi_buffers 64 4K;

  rewrite ^/caldav(.*)$ /remote.php/caldav$1 redirect;
  rewrite ^/carddav(.*)$ /remote.php/carddav$1 redirect;
  rewrite ^/webdav(.*)$ /remote.php/webdav$1 redirect;

  index index.php;
  error_page 403 = /core/templates/403.php;
  error_page 404 = /core/templates/404.php;

  location ~ ^/(data|config|\.ht|db_structure\.xml|README) {
    deny all;
  }

  location / {
    # The following 2 rules are only needed with webfinger
    rewrite ^/.well-known/host-meta /public.php?service=host-meta last;
    rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json
last;

    rewrite ^/.well-known/carddav /remote.php/carddav/ redirect;
    rewrite ^/.well-known/caldav /remote.php/caldav/ redirect;

    rewrite ^(/core/doc/[^\/]+/)$ $1/index.html;

    try_files $uri $uri/ index.php;
  }

  location ~ ^(.+?\.php)(/.*)?$ {
    try_files $1 = 404;

    include fastcgi_params;
    fastcgi_param PATH_INFO $2;
    fastcgi_param HTTPS on;
    # THIS LINE WAS ADDED
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_pass 127.0.0.1:9000;
    # Or use unix-socket with 'fastcgi_pass unix:/var/run/php5-fpm.sock;'
  }

  # Optional: set long EXPIRES header on static assets
  location ~* ^.+\.(jpg|jpeg|gif|bmp|ico|png|css|js|swf)$ {
    expires 30d;
    # Optional: Don't log access to assets
    access_log off;
  }

}
```
