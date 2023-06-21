#!/bin/bash -e
set -e

DATABASE_NAME=pg_mq_poc

# psql -c "drop database if exists $DATABASE_NAME;"
# psql -c "create database $DATABASE_NAME;"
# psql -c "CREATE EXTENSION IF NOT EXISTS hstore;"
psql -d $DATABASE_NAME -c "drop schema if exists mq cascade;"

for f in ./src/*.sql; do
    psql -f "$f" -d $DATABASE_NAME --single-transaction
done