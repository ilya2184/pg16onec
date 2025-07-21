#!/bin/bash

set -e

terminate_processes() {

    echo "Stoping postgres..."
    gosu postgres /opt/pgpro/1c-17/bin/pg_ctl -D "$PGDATA" stop

    pgagent_pid=$(ps -eo pid,cmd | grep 'pgagent' | grep -v grep | awk '{print $1}')
    if [ -n "$pgagent_pid" ]; then
        echo "Stopping pgagent $pgagent_pid ..."
        kill -SIGTERM "$pgagent_pid"
        wait "$pgagent_pid"
        echo "pgagent stopped."
    else
        echo "There is no pgagent PID"
    fi

    echo "Processes stopped."
    exit 0
}

trap 'terminate_processes' SIGTERM SIGINT

initialize_database() {
    if [ -s "$PGDATA/PG_VERSION" ]; then
        return
    fi
    chown -R postgres:postgres "$PGDATA"
    if [ -n "$PG_PASSWORD" ]; then
        gosu postgres sh -c 'echo "$PG_PASSWORD" > /tmp/password_file'
        gosu postgres ./initdb --pwfile=/tmp/password_file
    else
        gosu postgres ./initdb
    fi
    echo "synchronous_commit = off" >> "$PGDATA/postgresql.conf"
    echo "unix_socket_directories = '/tmp,$PGSOCKET'" >> "$PGDATA/postgresql.conf"
    echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf"
    echo "host  all  all  0.0.0.0/0  md5" >> "$PGDATA/pg_hba.conf"
    cat /pgdefault.conf >> /var/lib/1c/pgdata/postgresql.conf
    rm /pgdefault.conf
}

initialize_socket() {
    if [ -d "$PGSOCKET" ]; then
        chown postgres $PGSOCKET
        return
    fi
    mkdir -p $PGSOCKET
    chown postgres $PGSOCKET
}

start_processes() {
    echo "Staring pgagent..."
    gosu postgres pgagent -f host=$PGSOCKET dbname=postgres &
    pgagent_pid=$!
    echo "Starting postgres..."
    gosu postgres ./postgres &
    postgres_pid=$!
    wait "$postgres_pid"
}

if [ "$1" = './postgres' ]; then
    initialize_database
    initialize_socket
    start_processes
fi

exec "$@"
