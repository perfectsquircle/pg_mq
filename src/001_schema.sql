create extension if not exists hstore;

drop schema if exists mq cascade;
create schema mq;

-- TABLES 
create table mq.message (
    message_id bigserial primary key,
    routing_key text not null,
    payload jsonb not null,
    headers hstore not null default '',
    publish_time timestamptz not null default now()
);
create index on mq.message(publish_time);

create table mq.message_waiting (
    message_id bigint primary key references mq.message(message_id) on delete cascade,
    enqueue_time timestamptz not null default now()
);

create table mq.channel (
    channel_id bigserial primary key,
    channel_name text not null unique,
    maximum_messages int not null default 3
);

create table mq.channel_waiting (
    channel_id bigint not null references mq.channel(channel_id) on delete cascade,
    enqueue_time timestamptz not null default now()
);

create table mq.message_delivered (
    delivery_id bigserial primary key,
    message_id bigint not null references mq.message(message_id) on delete cascade,
    channel_id bigint not null references mq.channel(channel_id) on delete cascade,
    delivery_time timestamptz not null default now()
);

create table mq.message_complete (
    complete_time timestamptz not null default now(),
    success bool not null
) inherits (mq.message);

-- FUNCTIONS

CREATE OR REPLACE FUNCTION mq.notify_channel(delivery_id bigint, the_message_id bigint, channel_name text)
RETURNS VOID AS $$
DECLARE
  payload TEXT;
BEGIN
  select row_to_json(md) into payload 
    from (select delivery_id, m.* 
      from mq.message m
      where m.message_id = the_message_id) md;
  PERFORM pg_notify(channel_name, payload);
  RAISE NOTICE 'Sent to channel: %', channel_name;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mq.take_waiting_message()
RETURNS bigint AS $$
  DELETE FROM mq.message_waiting 
  WHERE message_id = (
    SELECT message_id FROM mq.message_waiting
    ORDER BY message_id
    FOR UPDATE SKIP LOCKED
    LIMIT 1
  ) RETURNING message_id;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION mq.take_waiting_channel()
RETURNS bigint AS $$
  DELETE FROM mq.channel 
  WHERE channel_id = (
    SELECT channel_id FROM mq.channel_waiting
    ORDER BY random()
    FOR UPDATE SKIP LOCKED
    LIMIT 1
  ) RETURNING channel_id;
$$ LANGUAGE SQL;


-- TRIGGERS

-- ENQUEUE

CREATE OR REPLACE FUNCTION mq.enqueue()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO mq.message_waiting(message_id)
  VALUES (NEW.message_id)
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enqueue_after_insert
AFTER INSERT ON mq.message
   FOR EACH ROW EXECUTE PROCEDURE mq.enqueue();

-- DELIVER MESSAGE

CREATE OR REPLACE FUNCTION mq.deliver_message()
RETURNS TRIGGER AS $$
BEGIN
  EXECUTE mq.notify_channel(NEW.delivery_id, NEW.message_id, text(NEW.channel_id));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER deliver_message_after_insert
BEFORE INSERT ON mq.message_delivered
   FOR EACH ROW EXECUTE PROCEDURE mq.deliver_message();

-- CHANNEL INITIALIZE
   
CREATE OR REPLACE FUNCTION mq.channel_initialize()
RETURNS TRIGGER AS $$
DECLARE
  selected_message_id bigint;
BEGIN
  FOR i IN 1..NEW.maximum_messages LOOP
    INSERT INTO mq.channel_waiting(channel_id)
      VALUES (NEW.channel_id);
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER channel_initialize_after_insert
AFTER INSERT ON mq.channel
   FOR EACH ROW EXECUTE PROCEDURE mq.channel_initialize();


-- MATCH MESSAGE

CREATE OR REPLACE FUNCTION mq.match_message()
RETURNS TRIGGER AS $$
DECLARE
  selected_message_id bigint;
BEGIN
  SELECT mq.take_waiting_message() INTO selected_message_id;
  IF selected_message_id IS NULL THEN
    RETURN NEW;
  END IF;
  INSERT INTO mq.message_delivered(message_id, channel_id)
      VALUES (selected_message_id, NEW.channel_id);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER match_message_before_insert
BEFORE INSERT ON mq.channel_waiting
  FOR EACH ROW EXECUTE PROCEDURE mq.match_message();