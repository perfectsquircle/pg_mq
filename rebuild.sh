#!/bin/bash -e

psql -c "drop database queue_baby;"
psql -c "create database queue_baby;"
psql -f src/001_schema.sql -d queue_baby
psql -f src/002_consumer_functions.sql -d queue_baby