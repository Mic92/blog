+++
title = "Owncloud 4 and Nginx"
date = "2012-06-03"
slug = "2012/06/03/owncloud-4-and-nginx"
Categories = ["nginx", "owncloud"]
+++

**updated at Do 14. Jul 2012**

Short after writing this entry, I discover [a good one][ntblock].

Nginx don't understand the .htaccess, which is shipped with owncloud. So some
rewrites, required by the webdav implementation, aren't applied. To get owncloud
running, some additional options are necessary:

## Nginx

```nginx nginx.conf
upstream backend {
      unix:/var/run/php-fpm.sock; # <--- edit me
}

# force https
server {
  listen         80;
  server_name    cloud.site.com;
  rewrite        ^ https://$server_name$request_uri? permanent;
}

server {
    listen 443 ssl;
    ssl_certificate /etc/ssl/nginx/nginx.crt;
    ssl_certificate_key /etc/ssl/nginx/nginx.key;

    server_name cloud.site.com; # <--- edit me
    root /var/web/MyOwncloud;   # <--- edit me
    index index.php;
    client_max_body_size 20M; # set maximum upload size

    access_log /var/log/nginx/cloud.access_log main;
    error_log /var/log/nginx/cloud.error_log info;

    location ~* ^.+.(jpg|jpeg|gif|bmp|ico|png|css|js|swf)$ {
      expires 30d;
      access_log off;
    }

    # deny direct access
    location ~ ^/(data|config|\.ht|db_structure.xml|README) {
      deny all;
    }

    location / {
      # these line replace the rewrite made in owncloud .htaccess
      try_files $uri $uri/ @webdav;
    }

    location @webdav {
      include fastcgi_params;
      fastcgi_pass backend;
      fastcgi_param HTTPS on;
      fastcgi_split_path_info ^(.+\.php)(/.*)$;
      fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
    }

    location ~ \.php$ {
      include fastcgi_params;
      fastcgi_pass backend;
      fastcgi_param HTTPS on;
      fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
    }
}
```

Additionally I added these lines to the default _/etc/nginx/fastcgi_params_:

```nginx
fastcgi_param  PATH_INFO          $fastcgi_path_info;
fastcgi_param  PATH_TRANSLATED    $document_root$fastcgi_path_info;
```

So it does looks like this:

```nginx /etc/nginx/fastcgi_params
fastcgi_param  PATH_INFO          $fastcgi_path_info;
fastcgi_param  PATH_TRANSLATED    $document_root$fastcgi_path_info;

fastcgi_param  QUERY_STRING       $query_string;
fastcgi_param  REQUEST_METHOD     $request_method;
fastcgi_param  CONTENT_TYPE       $content_type;
fastcgi_param  CONTENT_LENGTH     $content_length;

fastcgi_param  SCRIPT_NAME        $fastcgi_script_name;
fastcgi_param  REQUEST_URI        $request_uri;
fastcgi_param  DOCUMENT_URI       $document_uri;
fastcgi_param  DOCUMENT_ROOT      $document_root;
fastcgi_param  SERVER_PROTOCOL    $server_protocol;
fastcgi_param  HTTPS              $https if_not_empty;

fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
fastcgi_param  SERVER_SOFTWARE    nginx/$nginx_version;

fastcgi_param  REMOTE_ADDR        $remote_addr;
fastcgi_param  REMOTE_PORT        $remote_port;
fastcgi_param  SERVER_ADDR        $server_addr;
fastcgi_param  SERVER_PORT        $server_port;
fastcgi_param  SERVER_NAME        $server_name;

# PHP only, required if PHP was built with --enable-force-cgi-redirect
fastcgi_param  REDIRECT_STATUS    200;
```

PHP +++ If your upload size is still lower than the one set in nginx's
configuration, increase the size in the php.ini as described
[here](http://www.radinks.com/upload/config.php)

## References

[Setting up Nginx and Owncloud - nblock.org][ntblock]

[ntblock]: http://nblock.org/2012/03/12/nginx-and-owncloud
