#!/bin/bash -e
set -e

# psql -c "drop database pg_mq_poc;"
# psql -c "create database pg_mq_poc;"

for f in ./src/*.sql; do
    psql -f "$f" -d pg_mq_poc #--single-transaction
done