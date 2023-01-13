create extension if not exists hstore;

create schema mq;
SET search_path TO mq,public;

-- TABLES 
create table "message" (
    message_id bigserial primary key,
    sequence_key text,
    "key" text not null,
    payload jsonb not null,
    headers hstore not null default '',
    enqueue_time timestamptz not null default now(),
    status smallint not null default 0
);
create index on message(sequence_key);
create index on message(enqueue_time);
create index on message(status);
create index on message(status) where status = 0;

create table queue (
    message_id bigint not null references "message"(message_id) on delete cascade,
    sequence_key text not null unique
);

create table channel (
    channel_id bigserial primary key,
    channel_name text not null unique,
    prefetch int not null default 3
);

create table message_delivery (
    message_id bigint not null references "message"(message_id) on delete cascade,
    channel_name text not null references channel(channel_name) on delete cascade
);

-- FUNCTIONS

CREATE OR REPLACE FUNCTION f_enqueue()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO queue (message_id, sequence_key)
  VALUES (NEW.message_id, NEW.sequence_key)
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION f_dequeue()
RETURNS TRIGGER AS $$
DECLARE
  selected_channel TEXT;
BEGIN
  select c.channel_name into selected_channel 
      from channel c
      left join message_delivery md on c.channel_name = md.channel_name
      group by c.channel_name, c.prefetch
      having count(md) < c.prefetch
      order by random() 
      limit 1;
  RAISE NOTICE 'Selected channel: %', selected_channel;
  if selected_channel is null then
    return null;
  end if;
  INSERT INTO message_delivery (message_id, channel_name)
  VALUES (NEW.message_id, selected_channel)
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION f_deliver_message()
RETURNS TRIGGER AS $$
DECLARE
  payload TEXT;
BEGIN
  select row_to_json(m) into payload from message m where message_id = NEW.message_id;
  PERFORM pg_notify(NEW.channel_name, payload);
  RAISE NOTICE 'Sent to channel: %', NEW.channel_name;
  return NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION f_enqueue_next_message_in_sequence()
RETURNS TRIGGER AS $$
BEGIN
    insert into queue (
        select message_id, sequence_key
        from "message"
        where sequence_key = OLD.sequence_key
        and message_id > OLD.message_id
        order by message_id
        limit 1
    ) ON CONFLICT DO NOTHING;
    RETURN null;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION f_channel_revive()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO message_delivery (message_id, channel_name)
  SELECT q.message_id, NEW.channel_name FROM "queue" q
  LEFT JOIN message_delivery md ON md.message_id = q.message_id
  WHERE md IS NULL
  LIMIT NEW.prefetch;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- TRIGGERS

CREATE TRIGGER t_enqueue_after_insert
AFTER INSERT ON "message"
   FOR EACH ROW EXECUTE PROCEDURE f_enqueue();

CREATE TRIGGER t_dequeue_after_insert
AFTER INSERT ON "queue"
   FOR EACH ROW EXECUTE PROCEDURE f_dequeue();

CREATE TRIGGER t_deliver_message_after_insert
AFTER INSERT ON "message_delivery"
   FOR EACH ROW EXECUTE PROCEDURE f_deliver_message();

CREATE TRIGGER t_enqueue_next_after_delete
AFTER DELETE ON "queue"
   FOR EACH ROW EXECUTE PROCEDURE f_enqueue_next_message_in_sequence();
   
CREATE TRIGGER t_channel_revive_after_insert
AFTER INSERT ON "channel"
   FOR EACH ROW EXECUTE PROCEDURE f_channel_revive();