#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import select
import psycopg2
import psycopg2.extensions

import json


def db_listen():
    with psycopg2.connect(dbname='queue_baby', user='cfurano', host='localhost', port=5432, password='') as connection:
        with connection.cursor() as cur:
            cur.execute(
                'INSERT INTO channel(channel_name) VALUES (MD5(text(pg_backend_pid()))) RETURNING channel_name;')
            channel_name_row = cur.fetchone()
            cur.execute('LISTEN "' + channel_name_row[0] + '";')
            connection.commit()
            while True:
                select.select([connection], [], [], 1)
                connection.poll()
                while connection.notifies:
                    notification = connection.notifies.pop()
                    print(f"channel: {notification.channel }")
                    print(f"message: {notification.payload}")


db_listen()
