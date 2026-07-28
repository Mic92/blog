#!/bin/bash
# optional: load rvm
source "$HOME/.rvm/scripts/rvm" || source "/usr/local/rvm/scripts/rvm"

cd /tmp

BACKUP=/path/to/your/backup #<--- EDIT THIS LINE
TMPDIR=/tmp/$(mktemp -d chef-backup-XXXX)
MAX_BACKUPS=8

cd $TMPDIR
trap "rm -rf '$TMPDIR'" INT QUIT TERM EXIT
knife --config $HOME/.chef/knife-backup.rb backup export -D . >/dev/null
tar -cjf "$BACKUP/$(date +%m.%d.%Y).tar.bz2" .
# keep the last X backups
ls -t "$BACKUP" | tail -n+$MAX_BACKUPS | xargs rm -f
