-- TABLES 

CREATE TABLE mq.exchange (
    exchange_id serial PRIMARY KEY,
    exchange_name text NOT NULL UNIQUE
);

CREATE TABLE mq.message_intake (
    exchange_id int NOT NULL REFERENCES mq.exchange(exchange_id) ON DELETE CASCADE,
    routing_key text NOT NULL,
    payload json NOT NULL,
    headers hstore NOT NULL DEFAULT '',
    publish_time timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE mq.queue (
    queue_id bigserial PRIMARY KEY,
    exchange_id int NOT NULL REFERENCES mq.exchange(exchange_id),
    queue_name text NOT NULL UNIQUE,
    routing_key_pattern text NOT NULL DEFAULT '^.*$'
);

CREATE TABLE mq.message (
    message_id bigserial PRIMARY KEY,
    LIKE mq.message_intake,
    queue_id bigint NOT NULL REFERENCES mq.queue(queue_id) ON DELETE CASCADE
);
CREATE INDEX on mq.message(queue_id);

CREATE TABLE mq.message_waiting (
    message_id bigint PRIMARY KEY REFERENCES mq.message(message_id) ON DELETE CASCADE,
    queue_id bigint NOT NULL REFERENCES mq.queue(queue_id) ON DELETE CASCADE,
    since_time timestamptz NOT NULL DEFAULT now(),
    not_until_time timestamptz NULL
);
CREATE INDEX on mq.message_waiting(queue_id);

CREATE TABLE mq.channel (
    channel_id bigserial PRIMARY KEY,
    channel_name text NOT NULL UNIQUE,
    queue_id bigint NOT NULL REFERENCES mq.queue(queue_id) ON DELETE CASCADE,
    maximum_messages int NOT NULL DEFAULT 3
);

CREATE TABLE mq.channel_waiting (
    channel_id bigint NOT NULL REFERENCES mq.channel(channel_id) ON DELETE CASCADE,
    slot int NOT NULL,
    queue_id bigint NOT NULL REFERENCES mq.queue(queue_id) ON DELETE CASCADE,
    since_time timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY(channel_id, slot)
);
CREATE INDEX on mq.channel_waiting(queue_id);

CREATE TABLE mq.delivery (
    delivery_id bigserial PRIMARY KEY,
    message_id bigint NOT NULL REFERENCES mq.message(message_id) ON DELETE CASCADE,
    channel_id bigint NOT NULL REFERENCES mq.channel(channel_id) ON DELETE CASCADE,
    slot int NOT NULL,
    queue_id bigint NOT NULL REFERENCES mq.queue(queue_id) ON DELETE CASCADE,
    delivery_time timestamptz NOT NULL DEFAULT now()
);
