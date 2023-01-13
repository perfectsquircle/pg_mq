#!/bin/bash

psql -c "drop database queue_baby;"
psql -c "create database queue_baby;"
psql -f schema.sql -d queue_baby