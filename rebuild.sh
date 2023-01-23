#!/bin/bash -e
set -e

psql -c "drop database queue_baby;"
psql -c "create database queue_baby;"

for f in ./src/*.sql; do
    psql -f "$f" -d queue_baby #--single-transaction
done