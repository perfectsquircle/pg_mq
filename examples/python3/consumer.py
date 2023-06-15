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
                "SELECT mq.open_channel('Default Queue')")
            channel_id = cur.fetchone()[0]
            try:
                print(f"Listening to channel {channel_id}")
                connection.commit()
                select.select([connection], [], [], 1)
                connection.poll()
                while connection.notifies:
                    handle_message(connection, cur)
            finally:
                print(f'Closing channel {channel_id}')
                cur.execute(f'SELECT mq.close_channel({channel_id});')
                connection.commit()


def handle_message(connection, cur):
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
