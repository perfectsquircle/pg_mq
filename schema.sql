create extension if not exists hstore;

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

create table channels (
    channel_id bigserial primary key,
    channel_name text not null unique
);

insert into channels(channel_name)
values 
('default');

-- FUNCTIONS

CREATE OR REPLACE FUNCTION f_enqueue()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO queue (message_id, sequence_key)
  VALUES (NEW.message_id, NEW.sequence_key)
  ON CONFLICT DO NOTHING;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION f_dequeue()
RETURNS TRIGGER AS $$
DECLARE
  channel TEXT;
  payload TEXT;
BEGIN
  select channel_name into channel from channels order by random() limit 1;
  select row_to_json(m) into payload from message m where message_id = NEW.message_id;
  PERFORM pg_notify(channel, payload);
  return null;
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

-- TRIGGERS

CREATE TRIGGER t_enqueue_after_insert
AFTER INSERT ON "message"
   FOR EACH ROW EXECUTE PROCEDURE f_enqueue();

CREATE TRIGGER t_dequeue_after_insert
AFTER INSERT ON "queue"
   FOR EACH ROW EXECUTE PROCEDURE f_dequeue();

CREATE TRIGGER t_enqueue_next_after_delete
AFTER DELETE ON "queue"
   FOR EACH ROW EXECUTE PROCEDURE f_enqueue_next_message_in_sequence();