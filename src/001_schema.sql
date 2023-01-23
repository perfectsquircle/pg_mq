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

create table message_complete (
    complete_time timestamptz not null default now(),
    success bool not null
) inherits ("message");

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
    delivery_id bigserial primary key,
    slot_number int not null,
    channel_name text not null references channel(channel_name) on delete cascade,
    message_id bigint references "message"(message_id) on delete cascade,
    delivery_time timestamptz
);

-- FUNCTIONS

CREATE OR REPLACE FUNCTION f_enqueue()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO mq.queue (message_id, sequence_key)
  VALUES (NEW.message_id, NEW.sequence_key)
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION f_deliver_message()
RETURNS TRIGGER AS $$
DECLARE
  payload TEXT;
BEGIN
  IF NEW.message_id IS null THEN
    RETURN NEW;
  END IF;
  select row_to_json(m) into payload 
    from (select m.*, NEW.delivery_id FROM mq.message m 
          where m.message_id = NEW.message_id) m;
  PERFORM pg_notify(NEW.channel_name, payload);
  RAISE NOTICE 'Sent to channel: %', NEW.channel_name;
  return NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION f_new_delivery()
RETURNS TRIGGER AS $$
DECLARE
  payload TEXT;
BEGIN
  INSERT INTO mq.message_delivery(channel_name, slot_number)
  VALUES (OLD.channel_name, OLD.slot_number);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION take_ready_message()
RETURNS bigint AS $$
  DELETE FROM mq.queue 
  WHERE message_id = (
    SELECT message_id FROM mq.queue
    ORDER BY message_id
    FOR UPDATE SKIP LOCKED
    LIMIT 1
  ) RETURNING message_id;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION f_match_message()
RETURNS TRIGGER AS $$
DECLARE
  selected_message_id bigint;
  payload text;
BEGIN
  SELECT mq.take_ready_message() INTO selected_message_id;
  IF selected_message_id IS NULL THEN 
    RETURN NEW;
  END IF;

  NEW.message_id := selected_message_id;
  NEW.delivery_time := now();

  select row_to_json(m) into payload 
    from (select m.*, NEW.delivery_id FROM mq.message m 
          where m.message_id = selected_message_id) m;
  PERFORM pg_notify(NEW.channel_name, payload);
  RAISE NOTICE 'Sent to channel: %', NEW.channel_name;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION f_enqueue_next_message_in_sequence()
RETURNS TRIGGER AS $$
BEGIN
    insert into mq.queue (
        select message_id, sequence_key
        from mq.message
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
  INSERT INTO mq.message_delivery (channel_name, slot_number)
    SELECT NEW.channel_name, generate_series(1,NEW.prefetch);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- CREATE OR REPLACE FUNCTION f_dequeue()
-- RETURNS TRIGGER AS $$
-- DECLARE
--   selected_channel int;
-- BEGIN
--   SELECT find_open_channel() INTO selected_channel;
--   RAISE NOTICE 'Selected channel: %', selected_channel;
--   if selected_channel is null then
--     return null;
--   end if;
--   INSERT INTO mq.message_delivery (message_id, channel_name)
--     VALUES (NEW.message_id, selected_channel)
--     ON CONFLICT DO NOTHING;
--   RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION find_open_slot()
RETURNS bigint AS $$
DECLARE
  selected_channel int;
BEGIN
  SELECT channel_id INTO selected_channel
  FROM mq.message_delivery
  WHERE mq.message_id is null
  FOR UPDATE SKIP LOCKED;
  RETURN selected_channel;
END;
$$ LANGUAGE plpgsql;

-- TRIGGERS

CREATE TRIGGER t_enqueue_after_insert
AFTER INSERT ON "message"
   FOR EACH ROW EXECUTE PROCEDURE f_enqueue();

-- CREATE TRIGGER t_dequeue_after_insert
-- AFTER INSERT ON "queue"
--    FOR EACH ROW EXECUTE PROCEDURE f_dequeue();

CREATE TRIGGER t_deliver_message_after_update
AFTER UPDATE ON message_delivery
   FOR EACH ROW EXECUTE PROCEDURE f_deliver_message();

CREATE TRIGGER t_new_delivery_after_delete
AFTER DELETE ON message_delivery
   FOR EACH ROW EXECUTE PROCEDURE f_new_delivery();

CREATE TRIGGER t_match_message_before_insert
BEFORE INSERT ON message_delivery
   FOR EACH ROW EXECUTE PROCEDURE f_match_message();

CREATE TRIGGER t_enqueue_next_after_delete
AFTER DELETE ON "queue"
   FOR EACH ROW EXECUTE PROCEDURE f_enqueue_next_message_in_sequence();
   
CREATE TRIGGER t_channel_revive_after_insert
AFTER INSERT ON "channel"
   FOR EACH ROW EXECUTE PROCEDURE f_channel_revive();