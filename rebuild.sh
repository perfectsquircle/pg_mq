#!/bin/bash -e

psql -c "drop database queue_baby;"
psql -c "create database queue_baby;"
psql -f src/schema.sql -d queue_baby