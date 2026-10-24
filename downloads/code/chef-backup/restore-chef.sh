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
