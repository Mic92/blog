+++
title = "Icinga and Pnp4nagios With Nginx"
date = "2012-12-09"
slug = "2012/12/09/icinga-and-pnp4nagios-with-nginx"
Categories = ["icinga", "pnp4nagios", "nginx", "icinga-web"]
+++

In this article I will show my nginx configuration for the [icinga](https://www.icinga.org/) web interface. At the time of writing I installed version 1.8 on ubuntu 12.04 using this [ppa](https://launchpad.net/~formorer/+archive/icinga):

``` console
    $ sudo add-apt-repository ppa:formorer/icinga
    $ sudo add-apt-repository ppa:formorer/icinga-web
    $ sudo apt-get update
    # without --no-install-recommends, it will try to install apache
    $ sudo apt-get --no-install-recommends install icinga-web
    $ sudo apt-get install icinga-web-pnp # optional: for pnp4nagios
    $ sudo apt-get install nginx php5-fpm # if not already installed
```

For php I just use php-fpm without a special configuration.
If you installed icinga from source, you have change the roots to match your installation path (to `/usr/local/icinga-web/`)

``` nginx nginx.conf
upstream fpm {
    server unix:/var/run/php5-fpm.sock;
}

server {
    listen 80;
    listen 443 ssl;
    # FIXME
    server_name icinga.yourdomain.tld;

    access_log /var/log/nginx/icinga.access.log;
    error_log /var/log/nginx/icinga.error.log;
    # FIXME
    ssl_certificate /etc/ssl/private/icinga.yourdomain.tld.crt;
    ssl_certificate_key /etc/ssl/private/icinga.yourdomain.tld.pem;

    # Security - Basic configuration
    location = /favicon.ico {
      log_not_found off;
      access_log off;
      expires max;
    }

    location = /robots.txt {
      allow all;
      log_not_found off;
      access_log off;
    }

    # Deny access to hidden files
    location ~ /\. {
      deny all;
      access_log off;
      log_not_found off;
    }

    root /usr/share/icinga-web/pub;

    location /icinga-web/styles {
      alias /usr/share/icinga-web/pub/styles;
    }

    location /icinga-web/images {
      alias /usr/share/icinga-web/pub/images;
    }

    location /icinga-web/js {
      alias /usr/share/icinga-web/lib;
    }
    location /icinga-web/modules {
      rewrite ^/icinga-web/(.*)$ /index.php?/$1 last;
    }
    location /icinga-web/web {
      rewrite ^/icinga-web/(.*)$ /index.php?/$1 last;
    }

    #>>> configuration for pnp4nagios
    location /pnp4nagios {
      alias /usr/share/pnp4nagios/html;
    }

    location ~ ^(/pnp4nagios.*\.php)(.*)$ {
      root /usr/share/pnp4nagios/html;
      include fastcgi_params;
      fastcgi_split_path_info ^(.+\.php)(.*)$;
      fastcgi_param PATH_INFO $fastcgi_path_info;

      fastcgi_param SCRIPT_FILENAME $document_root/index.php;
      fastcgi_pass fpm;
    }
    #<<<

    location / {
      root   /usr/share/icinga-web/pub;
      index index.php;
      location ~* ^/(robots.txt|static|images) {
        break;
      }

      if ($uri !~ "^/(favicon.ico|robots.txt|static|index.php)") {
        rewrite ^/([^?]*)$ /index.php?/$1 last;
      }
    }

    location ~ \.php$ {
      include /etc/nginx/fastcgi_params;

      fastcgi_split_path_info ^(/icinga-web)(/.*)$;

      fastcgi_pass fpm;
      fastcgi_index index.php;
      include /etc/nginx/fastcgi_params;
    }
}
```
