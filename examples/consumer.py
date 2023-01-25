#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import select
import time
import psycopg2
import psycopg2.extensions

import json


def db_listen():
    with psycopg2.connect(dbname='pg_mq_poc', user='cfurano', host='localhost', port=5432, password='') as connection:
        with connection.cursor() as cur:
            cur.execute(
                'SELECT mq.register_channel()')
            channel_name_row = cur.fetchone()
            print(f"Listening to channel {channel_name_row[0]}")
            cur.execute(f'LISTEN "{channel_name_row[0]}";')
            connection.commit()
            while True:
                select.select([connection], [], [], 1)
                connection.poll()
                while connection.notifies:
                    notification = connection.notifies.pop()
                    delivered_message = json.loads(notification.payload)
                    print(f"channel: {notification.channel }")
                    print(f"message: {delivered_message}")
                    time.sleep(0.25)
                    cur.execute(
                        f"SELECT mq.ack({delivered_message['delivery_id']}, true)")
                    connection.commit()
                    print('message acked.')


db_listen()
