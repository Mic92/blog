+++
title = "Automated Backups for Chef Server"
date = "2013-04-27"
slug = "2013/04/27/automated-backups-for-chef-server"
Categories = ["chef", "opscode", "backup", "cron", "knife-backup"]
+++

In this article I will share my setup, I use to backup chef server.
In the best case, you have a dedicated machine, which has network access to your chef
server. Otherwise you will have to additionally use a different backup program
like [rsnapshot](http://www.rsnapshot.org/) or
[duplicity](http://duplicity.nongnu.org/) to backup the created export
directory. In my case I use a raspberry pie with a
[hdd docking station](http://www.amazon.de/dp/B0017J4IAQ?tag=gitblo-21) and a
[power saving harddrive](http://www.amazon.de/dp/B004VFJ9MK?tag=gitblo-21)

To get started you will need ruby on the backup machine. I prefer using rvm for
this job. Feel free to choose your preferred way:

```console
$ curl -L https://get.rvm.io | bash -s stable --autolibs=enabled
```

To create the backup, I use the great [knife-backup gem](https://github.com/mdxp/knife-backup) of [Marius Ducea](http://www.ducea.com/):

```console
$ gem install knife-backup
```

Then add these scripts to your system:

```console
$ mkdir -p ~/bin && cd ~/bin
$ wget http://blog.higgsboson.tk/downloads/code/chef-backup/backup-chef.sh
$ wget http://blog.higgsboson.tk/downloads/code/chef-backup/restore-chef.sh
$ chmod +x {backup,restore}-chef.sh
```

```bash
#!/bin/bash
# optional: load rvm
source "$HOME/.rvm/scripts/rvm" || source "/usr/local/rvm/scripts/rvm"

cd /tmp

BACKUP=/path/to/your/backup #&lt;--- EDIT THIS LINE
TMPDIR=/tmp/$(mktemp -d chef-backup-XXXX)
MAX_BACKUPS=8

cd $TMPDIR
trap "rm -rf '$TMPDIR'" INT QUIT TERM EXIT
knife --config $HOME/.chef/knife-backup.rb backup export -D . &gt;/dev/null
tar -cjf "$BACKUP/$(date +%m.%d.%Y).tar.bz2" .
# keep the last X backups
ls -t "$BACKUP" | tail -n+$MAX_BACKUPS | xargs rm -f
```

```bash
#!/bin/bash

if [ "$#" -eq 0 ]; then
    echo "USAGE: $0 /path/to/backup"
    exit 1
fi

source "$HOME/.rvm/scripts/rvm" || source "/usr/local/rvm/scripts/rvm"

cd /tmp
TMPDIR=/tmp/$(mktemp -d chef-restore-XXXX)

cd "$TMPDIR"
trap "rm -rf '$TMPDIR'" INT QUIT TERM EXIT
tar xf $1
knife --config $HOME/.chef/knife-backup.rb backup restore -D .
```

Modify BACKUP variable to match your backup destination.
Next you will need a knife.rb to get access to your server.
I suggest to create a new client:

```console
$ mkdir -p ~/.chef
$ knife client create backup --admin --file "$HOME/.chef/backup.pem"
$ cat <<'__EOF__' >> ~/.chef/knife-backup.rb
log_level                :info
log_location             STDOUT
node_name                'backup'
client_key               "#{ENV["HOME"]}/.chef/backup.pem"
chef_server_url          'https://chef.yourdomain.tld' # EDIT HERE
syntax_check_cache_path  "#{ENV["HOME"]}.chef/syntax_check_cache"
__EOF__
$ knife role list # test authentication
```

Now test the whole setup, by running the `backup-chef.sh` script:

```console
$ ~/bin/backup-chef.sh
```

It should create a tar file in the backup directory.

If everything works, you can add a cronjob to automate this.

```console
$ crontab -e
```

```
@daily $HOME/bin/backup-chef.sh
```

To restore a backup simply run (where `DATE` is the date of the backup)

```console
$ ~/bin/restore-chef.sh /path/to/backup/DATE.tar.bz2
```

That's all folks!
