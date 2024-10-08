#!/bin/bash

set -e

if [ "$1" = './postgres' ]; then

    if [ ! -s "$PGDATA/PG_VERSION" ]; then
        chown -R postgres:postgres "$PGDATA"

        if [ -n "$PG_PASSWORD" ]; then
            gosu postgres sh -c 'echo "$PG_PASSWORD" > /tmp/password_file'
            gosu postgres ./initdb --pwfile=/tmp/password_file
        else
            gosu postgres ./initdb
        fi

        echo "synchronous_commit = off" >> "$PGDATA/postgresql.conf"
        echo "unix_socket_directories = '/tmp,$PGSOCKET'" >> "$PGDATA/postgresql.conf"
        # listen all network addresses
        echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf"
        # enable login-password auth for all
        echo "host  all  all  0.0.0.0/0  md5" >> "$PGDATA/pg_hba.conf"
        # need to set default password after start
    fi

    if [ ! -d "$PGSOCKET" ]; then
        mkdir -p $PGSOCKET
    fi
    chown postgres $PGSOCKET

    # gosu postgres pgagent host=$PGSOCKET dbname=postgres &

    echo "Statring postgres..."
    exec gosu postgres ./postgres

fi

exec "$@"
